import { Injectable, Logger } from '@nestjs/common';
import * as OSS from 'ali-oss';

@Injectable()
export class OssService {
  private client: OSS;
  private readonly logger = new Logger(OssService.name);

  constructor() {
    // Ideally, these should be loaded from environment variables (ConfigService)
    this.client = new OSS({
      region: process.env.ALIYUN_OSS_REGION || 'oss-cn-hangzhou',
      accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || 'your_access_key_id',
      accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || 'your_access_key_secret',
      bucket: process.env.ALIYUN_OSS_BUCKET || 'your_bucket_name',
    });
  }

  /**
   * Generate a presigned URL for uploading a file (PUT)
   * @param objectName The name of the object in OSS (e.g., 'avatars/123.jpg')
   * @param fileType MIME type of the file
   * @param expires Expiration time in seconds (default 3600)
   * @returns The presigned URL
   */
  async generatePresignedUrl(objectName: string, fileType: string, expires: number = 300): Promise<string> {
    try {
      const url = this.client.signatureUrl(objectName, {
        method: 'PUT',
        expires: expires,
        'Content-Type': fileType,
      });
      this.logger.log(`Generated presigned URL for ${objectName}`);
      return url;
    } catch (error) {
      this.logger.error(`Error generating presigned URL: ${error}`);
      throw error;
    }
  }

  /**
   * Generate a presigned URL for downloading/viewing a file (GET)
   * @param objectName The name of the object in OSS
   * @param expires Expiration time in seconds
   */
  async generateGetUrl(objectName: string, expires: number = 3600): Promise<string> {
    try {
      const url = this.client.signatureUrl(objectName, {
        expires: expires,
      });
      return url;
    } catch (error) {
      this.logger.error(`Error generating GET URL: ${error}`);
      throw error;
    }
  }
}
