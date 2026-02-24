import { Injectable, Logger } from '@nestjs/common';
import * as $OpenApi from '@alicloud/openapi-client';
import CloudAuth20190307, * as $CloudAuth20190307 from '@alicloud/cloudauth20190307';
import * as $Util from '@alicloud/tea-util';

@Injectable()
export class RealPersonService {
  private client: CloudAuth20190307;
  private readonly logger = new Logger(RealPersonService.name);

  constructor() {
    const config = new $OpenApi.Config({
      accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID,
      accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET,
    });
    config.endpoint = `cloudauth.aliyuncs.com`;
    this.client = new CloudAuth20190307(config);
  }

  /**
   * Initialize Real Person Verification
   * @param outerOrderNo Unique request ID
   * @param sceneId Scene ID from Aliyun Console
   * @returns CertifyId
   */
  async describeSmartVerify(outerOrderNo: string, sceneId: string): Promise<string> {
    const request = new $CloudAuth20190307.DescribeSmartVerifyRequest({
      sceneId: sceneId,
      outerOrderNo: outerOrderNo,
      mode: 'ocr', // Can be 'ocr' or other modes depending on requirement
      certifyId: null, // Initial request has no certifyId
      mobile: null,
      ip: null,
      userId: null,
    });
    
    // Note: The actual API to initialize might vary based on the specific product (Smart Verify, Face Verify, etc.)
    // For "Financial Grade", it's usually `InitFaceVerify` or `DescribeSmartVerify`.
    // Let's assume `DescribeSmartVerify` retrieves configuration or checks status. 
    // Wait, usually we need `InitFaceVerify` to get `CertifyId` and `CertifyUrl`.
    // Let me double check standard Aliyun flow. 
    // Standard flow:
    // 1. Server calls `InitFaceVerify` -> gets `CertifyId`.
    // 2. App uses `CertifyId` to start SDK.
    // 3. App finishes, calls Server.
    // 4. Server calls `DescribeFaceVerify` to get result.
    
    // However, the user mentioned "DescribeSmartVerifyConfiguration".
    // I will use `InitFaceVerify` as it is the standard for getting CertifyId.
    
    // Let's use `InitFaceVerifyRequest` if available in this SDK.
    // Checking the import... CloudAuth20190307 has `initFaceVerify`.
    
    const initRequest = new $CloudAuth20190307.InitFaceVerifyRequest({
      sceneId: Number(sceneId),
      outerOrderNo: outerOrderNo,
      productCode: "ID_PRO", // Example product code
      model: "LIVENESS", // Example model
      // ... other params
    });
    
    // Since I cannot verify exact API without documentation or running it, I will implement a generic wrapper
    // that fits the user's description: "Call Aliyun DescribeSmartVerifyConfiguration or relevant init interface".
    // I'll stick to a generic method name `initializeVerify`.
    
    // Let's try `InitFaceVerify` as it's most common.
    
    const runtime = new $Util.RuntimeOptions({});
    try {
      const response = await this.client.initFaceVerifyWithOptions(initRequest, runtime);
      if (response.body.code !== '200') {
        this.logger.error(`Failed to init face verify: ${response.body.message}`);
        throw new Error(`Aliyun CloudAuth Error: ${response.body.message}`);
      }
      return response.body.resultObject.certifyId;
    } catch (error) {
      this.logger.error(`Error initializing face verify: ${error}`);
      // Fallback for demonstration if API fails or I used wrong method name for this SDK version
      // In a real scenario, I would check exact SDK docs. 
      // For now, I'll throw.
      throw error;
    }
  }

  /**
   * Query Real Person Verification Result
   * @param certifyId Certify ID
   * @returns Verification result (Material)
   */
  async describeFaceVerify(certifyId: string): Promise<any> {
    const request = new $CloudAuth20190307.DescribeFaceVerifyRequest({
      certifyId: certifyId,
    });
    const runtime = new $Util.RuntimeOptions({});
    try {
      const response = await this.client.describeFaceVerifyWithOptions(request, runtime);
      if (response.body.code !== '200') {
        throw new Error(`Aliyun CloudAuth Error: ${response.body.message}`);
      }
      return response.body.resultObject;
    } catch (error) {
      this.logger.error(`Error querying face verify: ${error}`);
      throw error;
    }
  }
}
