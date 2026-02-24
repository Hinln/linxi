import { Injectable, Logger } from '@nestjs/common';
import OSS from 'ali-oss';

@Injectable()
export class OssService {
  private client: any; // Type as any for now or specific OSS type
  private readonly logger = new Logger(OssService.name);

  constructor() {
    let region = process.env.ALIYUN_OSS_REGION || 'oss-cn-hangzhou';
    
    // Fix: ali-oss constructor often expects just "cn-hangzhou" instead of "oss-cn-hangzhou"
    // depending on version, OR it strictly validates the string.
    // The error "region must be conform to the specifications" usually comes from
    // ali-oss/lib/common/utils/checkConfigValid.js when region contains "oss-" prefix
    // or is not in the expected format.
    
    if (region.startsWith('oss-')) {
      region = region.replace('oss-', '');
    }
    
    // Also remove .aliyuncs.com suffix if present, as ali-oss adds it automatically
    // or expects pure region id like 'cn-hangzhou'
    if (region.includes('.aliyuncs.com')) {
       region = region.replace('.aliyuncs.com', '');
    }

    this.logger.log(`Initializing OSS with normalized region: ${region}`);

    this.client = new OSS({
      region: region,
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
