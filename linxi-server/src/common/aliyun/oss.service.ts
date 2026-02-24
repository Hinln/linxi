import { Injectable, Logger } from '@nestjs/common';
import * as OSS from 'ali-oss';

@Injectable()
export class OssService {
  private client: any; // Type as any for now or specific OSS type
  private readonly logger = new Logger(OssService.name);

  constructor() {
    this.client = new OSS({
      region: process.env.ALIYUN_OSS_REGION || 'oss-cn-hangzhou',
      accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID,
      accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET,
      bucket: process.env.ALIYUN_OSS_BUCKET,
    });
  }

  async generatePresignedUrl(objectName: string, fileType: string): Promise<string> {
    try {
      // Ensure Content-Type matches what client will send
      const url = this.client.signatureUrl(objectName, {
        method: 'PUT',
        'Content-Type': fileType, // Critical: Must match client's Header
        expires: 3600, 
      });
      return url;
    } catch (error) {
      this.logger.error(`Error generating presigned URL: ${error}`);
      throw error;
    }
  }
}
