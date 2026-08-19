// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  // Backend API URL (aligned with ProductService and OrderService)
  static const String baseUrl = ApiConfig.authUrl;

  /// Performs login via API or local credentials verification
  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username_or_email': usernameOrEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final user = data['user'] ?? {};
          await saveUserSession({
            'username': user['username'] ?? usernameOrEmail,
            'email': user['email'] ?? usernameOrEmail,
            'store_name': user['store_name'] ?? 'My Store',
            'store_address': user['store_address'] ?? '123 Main Street, City',
            'phone': user['phone'] ?? '+63 912 345 6789',
            'role': user['role'] ?? 'Admin',
          });
          return {'success': true, 'message': data['message'] ?? 'Login successful'};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Invalid credentials'};
        }
      }
    } catch (_) {
      // If network fails / backend is offline, check local SharedPreferences
    }

    // Fallback to local session / saved user
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? '';
    final savedUsername = prefs.getString('username') ?? '';
    final savedPassword = prefs.getString('password') ?? '';

    // If local user exists and matches
    if ((usernameOrEmail == savedEmail || usernameOrEmail == savedUsername) &&
        (savedPassword.isEmpty || savedPassword == password)) {
      await prefs.setBool('is_logged_in', true);
      return {'success': true, 'message': 'Login successful (Offline mode)'};
    }

    // Default demo login fallback if credentials are provided
    if (usernameOrEmail.isNotEmpty && password.isNotEmpty) {
      // Save provided credentials for demo/offline use
      await saveUserSession({
        'username': usernameOrEmail.contains('@')
            ? usernameOrEmail.split('@').first
            : usernameOrEmail,
        'email': usernameOrEmail.contains('@')
            ? usernameOrEmail
            : '$usernameOrEmail@example.com',
        'store_name': prefs.getString('store_name') ?? 'My Store',
        'store_address':
            prefs.getString('store_address') ?? '123 Main Street, City',
        'phone': prefs.getString('phone') ?? '+63 912 345 6789',
        'role': prefs.getString('role') ?? 'Admin',
      });
      await prefs.setString('password', password);
      return {'success': true, 'message': 'Login successful'};
    }

    return {'success': false, 'message': 'Invalid username/email or password'};
  }

  /// Registers a new account via API or local storage
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String storeName,
    required String phone,
    String storeAddress = '123 Main Street, City',
    String role = 'Admin',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
              'store_name': storeName,
              'phone': phone,
              'store_address': storeAddress,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await saveUserSession({
            'username': username,
            'email': email,
            'store_name': storeName,
            'store_address': storeAddress,
            'phone': phone,
            'role': role,
          });
          return {'success': true, 'message': data['message'] ?? 'Registration successful'};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Registration failed'};
        }
      }
    } catch (_) {
      // Backend offline fallback
    }

    // Local registration fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', password);
    await saveUserSession({
      'username': username,
      'email': email,
      'store_name': storeName,
      'store_address': storeAddress,
      'phone': phone,
      'role': role,
    });

    return {'success': true, 'message': 'Account registered successfully'};
  }

  /// Saves user profile and login state in SharedPreferences
  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    if (userData['username'] != null) {
      await prefs.setString('username', userData['username'].toString());
    }
    if (userData['email'] != null) {
      await prefs.setString('email', userData['email'].toString());
    }
    if (userData['store_name'] != null) {
      await prefs.setString('store_name', userData['store_name'].toString());
    }
    if (userData['store_address'] != null) {
      await prefs.setString(
          'store_address', userData['store_address'].toString());
    }
    if (userData['phone'] != null) {
      await prefs.setString('phone', userData['phone'].toString());
    }
    if (userData['role'] != null) {
      await prefs.setString('role', userData['role'].toString());
    }
    await prefs.setBool('is_logged_in', true);
  }

  /// Checks if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  /// Logs out user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }
}
