import { Controller, Get, Post, Body, Request } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { RechargeDto, CallbackDto } from './dto/wallet.dto';
import { Public } from '../auth/public.decorator';

@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('balance')
  async getBalance(@Request() req) {
    return this.walletService.getBalance(req.user.userId);
  }

  @Post('recharge')
  async createRechargeOrder(@Request() req, @Body() rechargeDto: RechargeDto) {
    return this.walletService.createRechargeOrder(req.user.userId, rechargeDto);
  }

  @Public()
  @Post('callback')
  async handleCallback(@Body() callbackDto: CallbackDto) {
    return this.walletService.handleCallback(callbackDto);
  }
}
