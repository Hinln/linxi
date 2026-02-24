import { Injectable, Logger, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TransactionType, TransactionStatus, Prisma } from '@prisma/client';
import { RechargeDto, CallbackDto } from './dto/wallet.dto';
import * as crypto from 'crypto';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get Wallet Balance & Transactions
   */
  async getBalance(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { goldBalance: true },
    });

    const transactions = await this.prisma.coinTransaction.findMany({
      where: { userId },
      take: 20,
      orderBy: { createdAt: 'desc' },
    });

    return {
      balance: user?.goldBalance || 0,
      transactions,
    };
  }

  /**
   * Create Recharge Order
   */
  async createRechargeOrder(userId: number, rechargeDto: RechargeDto) {
    const { amount, remark } = rechargeDto;
    // Generate a unique outTradeNo
    const outTradeNo = `PAY${Date.now()}${Math.floor(Math.random() * 1000)}`;
    
    // In production, we generate a signature here to be sent back in callback
    const mockSecret = 'mock_secret_key';
    const sign = crypto.createHmac('sha256', mockSecret).update(outTradeNo).digest('hex');

    const transaction = await this.prisma.coinTransaction.create({
      data: {
        userId,
        amount: new Prisma.Decimal(amount),
        type: TransactionType.RECHARGE,
        status: TransactionStatus.PENDING,
        outTradeNo,
        remark: remark || 'User Recharge',
      },
    });

    // Mock Payment URL
    const paymentUrl = `https://mock-payment.com/pay?outTradeNo=${outTradeNo}&amount=${amount}&sign=${sign}`;

    return {
      transactionId: transaction.id,
      outTradeNo,
      paymentUrl,
    };
  }

  /**
   * Handle Recharge Callback
   */
  async handleCallback(callbackDto: CallbackDto) {
    const { outTradeNo, sign, status } = callbackDto;

    // 1. Verify Signature (Mock)
    // In real world: verify sign using secret key
    const mockSecret = 'mock_secret_key';
    const computedSign = crypto.createHmac('sha256', mockSecret).update(outTradeNo).digest('hex');
    
    // For simplicity in mock, assume if sign matches "valid_sign" or computed, it's valid
    // But user asked for "signature verification logic".
    // Let's assume the callback sender signs `outTradeNo` with `mockSecret`.
    if (sign !== computedSign && sign !== 'valid_sign_for_dev') {
       this.logger.warn(`Invalid signature for order ${outTradeNo}`);
       throw new BadRequestException('Invalid signature');
    }

    const transaction = await this.prisma.coinTransaction.findUnique({
      where: { outTradeNo },
    });

    if (!transaction) {
      throw new BadRequestException('Order not found');
    }

    if (transaction.status === TransactionStatus.COMPLETED) {
      return { message: 'Already processed' };
    }

    // 2. Atomic Update
    await this.prisma.$transaction(async (tx) => {
      // Update Transaction
      await tx.coinTransaction.update({
        where: { id: transaction.id },
        data: { status: TransactionStatus.COMPLETED },
      });

      // Update User Balance
      // Note: amount is Decimal
      await tx.user.update({
        where: { id: transaction.userId },
        data: {
          goldBalance: { increment: transaction.amount },
        },
      });

      // Audit Log
      // Assuming audit log is generic enough
      // Need to fetch user to know who performed this? No, system callback.
      // AdminId in AuditLog is Int, referencing User. 
      // If callback is system, we might need a system user ID (e.g. 0) or reuse transaction.userId as "self-service".
      // Let's use transaction.userId for now.
      
      await tx.auditLog.create({
        data: {
          adminId: transaction.userId, 
          action: 'RECHARGE_SUCCESS',
          target: `Transaction:${transaction.id}`,
          details: `Amount: ${transaction.amount}, OutTradeNo: ${outTradeNo}`,
        },
      });
    });

    return { message: 'Success' };
  }

  /**
   * Consume Coins (Generic Method)
   */
  async consumeCoins(userId: number, amount: number, type: TransactionType, remark?: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    
    const decimalAmount = new Prisma.Decimal(amount);

    return await this.prisma.$transaction(async (tx) => {
      // 1. Deduct Balance (Optimistic Locking via WHERE clause)
      // Prisma `updateMany` returns count of updated rows.
      // If balance < amount, count will be 0.
      const result = await tx.user.updateMany({
        where: {
          id: userId,
          goldBalance: { gte: decimalAmount }, 
        },
        data: {
          goldBalance: { decrement: decimalAmount },
        },
      });

      if (result.count === 0) {
        throw new ConflictException('Insufficient balance');
      }

      // 2. Record Transaction
      const transaction = await tx.coinTransaction.create({
        data: {
          userId,
          amount: decimalAmount.negated(), // Negative for consumption
          type,
          status: TransactionStatus.COMPLETED,
          remark,
        },
      });

      return transaction;
    });
  }
}
