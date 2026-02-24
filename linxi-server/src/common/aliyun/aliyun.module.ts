import { Module } from '@nestjs/common';
import { SmsService } from './sms.service';
import { OssService } from './oss.service';
import { RealPersonService } from './real-person.service';

@Module({
  providers: [SmsService, OssService, RealPersonService],
  exports: [SmsService, OssService, RealPersonService],
})
export class AliyunModule {}
