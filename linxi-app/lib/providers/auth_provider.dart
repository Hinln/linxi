import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _token;
  String? get token => _token;

  Future<bool> sendCode(String phone) async {
    _setLoading(true);
    try {
      final response = await ApiService().post('/auth/send-code', data: {'phone': phone});
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Send Code Error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String phone, String code) async {
    _setLoading(true);
    try {
      final response = await ApiService().post('/auth/login', data: {
        'phone': phone,
        'code': code,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final token = data['token']; // Adjust based on your API response structure
        
        if (token != null) {
          _token = token;
          await _saveToken(token);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Login Error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    notifyListeners();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
