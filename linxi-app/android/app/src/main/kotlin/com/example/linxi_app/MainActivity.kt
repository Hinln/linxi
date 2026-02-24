package com.example.linxi_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.aliyun.aliyun_face_plugin.face.AliyunFaceAuthFacade
import com.aliyun.aliyun_face_plugin.face.AliyunFaceAuthCallback
import com.aliyun.aliyun_face_plugin.face.AliyunResponse

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.linxi.app/face_verify"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Aliyun Face Auth Facade
        AliyunFaceAuthFacade.init(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMetaInfo" -> {
                    val metaInfo = AliyunFaceAuthFacade.getMetaInfo(this)
                    result.success(metaInfo)
                }
                "startFaceVerify" -> {
                    val verifyId = call.argument<String>("verifyId")
                    val verifyToken = call.argument<String>("verifyToken")
                    
                    if (verifyId != null && verifyToken != null) {
                        AliyunFaceAuthFacade.verify(this, verifyId, verifyToken, object : AliyunFaceAuthCallback {
                            override fun onInit(code: String) {
                                // Init callback
                            }

                            override fun onLoading() {
                                // Loading callback
                            }

                            override fun onFinish(response: AliyunResponse) {
                                if (response.code == "1000") { // Success code, adjust based on SDK docs
                                    result.success("success")
                                } else {
                                    result.error(response.code, response.message, null)
                                }
                            }
                        })
                    } else {
                        result.error("INVALID_ARGS", "Missing verifyId or verifyToken", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
