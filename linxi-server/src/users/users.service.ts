import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoUtil } from '../common/utils/crypto.util';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findOne(id: number) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        phone: true,
        nickname: true,
        avatarUrl: true,
        verifyStatus: true,
        goldBalance: true,
      },
    });
    if (!user) {
      throw new NotFoundException(`User #${id} not found`);
    }
    return user;
  }

  async updateRealPersonInfo(id: number, realName: string, idCardNumber: string, certifyId: string) {
    const encryptedRealName = CryptoUtil.encrypt(realName);
    const encryptedIdCard = CryptoUtil.encrypt(idCardNumber);

    return this.prisma.user.update({
      where: { id },
      data: {
        realName: encryptedRealName,
        idCardNumber: encryptedIdCard,
        certifyId: certifyId,
        verifyStatus: 'VERIFIED', // Assuming direct verification or PENDING based on flow
      },
    });
  }
}
