import { Injectable, Logger } from '@nestjs/common';
import Dysmsapi20170525, * as $Dysmsapi20170525 from '@alicloud/dysmsapi20170525';
import * as $OpenApi from '@alicloud/openapi-client';
import * as $Util from '@alicloud/tea-util';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class SmsService {
  private client: Dysmsapi20170525;
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly redisService: RedisService) {
    // Ideally, these should be loaded from environment variables (ConfigService)
    const config = new $OpenApi.Config({
      accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || 'your_access_key_id',
      accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || 'your_access_key_secret',
    });
    // Endpoint for Dysmsapi
    config.endpoint = `dysmsapi.aliyuncs.com`;
    this.client = new Dysmsapi20170525(config);
  }

  /**
   * Send SMS verification code
   * @param phoneNumber Recipient phone number
   * @param signName SMS Sign Name
   * @param templateCode SMS Template Code
   * @param templateParam JSON string of template parameters, e.g., '{"code":"1234"}'
   */
  async sendSms(phoneNumber: string, signName: string, templateCode: string, templateParam: string): Promise<void> {
    const sendSmsRequest = new $Dysmsapi20170525.SendSmsRequest({
      phoneNumbers: phoneNumber,
      signName: signName,
      templateCode: templateCode,
      templateParam: templateParam,
    });

    const runtime = new $Util.RuntimeOptions({});
    try {
      const response = await this.client.sendSmsWithOptions(sendSmsRequest, runtime);
      if (response.body.code !== 'OK') {
        this.logger.error(`Failed to send SMS: ${response.body.message}`);
        throw new Error(`Aliyun SMS Error: ${response.body.message}`);
      }
      this.logger.log(`SMS sent successfully to ${phoneNumber}`);
    } catch (error) {
      this.logger.error(`Error sending SMS: ${error}`);
      throw error;
    }
  }

  /**
   * Verify SMS code
   * @param phoneNumber Phone number
   * @param code Verification code
   * @returns boolean
   */
  async verifyCode(phoneNumber: string, code: string): Promise<boolean> {
    const key = `sms:code:${phoneNumber}`;
    const storedCode = await this.redisService.get(key);
    
    // In development mode, if redis is empty or code matches specific value, we might want to bypass
    // But for production logic:
    if (storedCode && storedCode === code) {
      await this.redisService.del(key); // Invalidate code after usage
      return true;
    }
    return false;
  }
}
