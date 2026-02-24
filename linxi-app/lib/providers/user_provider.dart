import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../core/models/user_model.dart';
import '../core/native_bridge.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  final ApiService _api = ApiService();

  Future<void> loadUser() async {
    _setLoading(true);
    try {
      // Assuming GET /users/me returns the user profile
      final response = await _api.get('/users/me');
      if (response.statusCode == 200) {
        _user = User.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Load User Error: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshBalance() async {
    try {
      // Assuming GET /wallet/balance returns { balance: 100.0 } or similar
      // Or we can just reload the full user profile
      await loadUser(); 
    } catch (e) {
      if (kDebugMode) {
        print('Refresh Balance Error: $e');
      }
    }
  }

  Future<String?> recharge(double amount) async {
    _setLoading(true);
    try {
      final response = await _api.post('/wallet/recharge', data: {
        'amount': amount,
      });
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Mock payment flow: in a real app, we'd open a webview or SDK with the returned payUrl/orderInfo
        // For now, let's assume it "succeeds" instantly or returns a URL to display.
        // The prompt says "模拟调用", implying we just hit the API.
        
        // After "payment", refresh balance
        await Future.delayed(const Duration(seconds: 2)); // Simulate payment delay
        await refreshBalance();
        return null; // Success
      }
      return 'Recharge failed';
    } catch (e) {
      return 'Error: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startRealNameVerification() async {
    _setLoading(true);
    try {
      // 1. Get MetaInfo from Native SDK
      final metaInfo = await NativeBridge.getMetaInfo();

      // 2. Get Verify ID and Token from backend, sending metaInfo
      final response = await _api.post('/auth/real-name/initialize', data: {
        'metaInfo': metaInfo,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final verifyId = data['verifyId'];
        final verifyToken = data['verifyToken'];

        // 3. Call Native SDK to start verify
        if (verifyId != null && verifyToken != null) {
           await NativeBridge.startFaceVerify(verifyId, verifyToken);
           // 4. Refresh status after verification
           await loadUser();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Real Name Verify Error: $e');
      }
      // Rethrow or handle error to show UI feedback
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
