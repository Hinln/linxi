import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.linxi.app/face_verify');

  /// Gets the MetaInfo required for initialization.
  static Future<String> getMetaInfo() async {
    try {
      final String metaInfo = await _channel.invokeMethod('getMetaInfo');
      return metaInfo;
    } on PlatformException catch (e) {
      throw 'Failed to get meta info: ${e.message}';
    }
  }

  /// Starts the face verification process.
  /// 
  /// Returns a [Future] that completes with the verification result.
  /// The result format depends on the native implementation.
  /// Typically returns a String or Map.
  static Future<dynamic> startFaceVerify(String verifyId, String verifyToken) async {
    try {
      final result = await _channel.invokeMethod('startFaceVerify', {
        'verifyId': verifyId,
        'verifyToken': verifyToken,
      });
      return result;
    } on PlatformException catch (e) {
      throw 'Failed to verify face: ${e.message}';
    }
  }
}
