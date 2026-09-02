// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AuthService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Returns the current logged in user ID
  static Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? 1;
  }

  /// Performs offline login via SQLite users table and stores session
  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final user = await _db.authenticateUser(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      if (user != null) {
        final userId = user['id'] is int
            ? user['id'] as int
            : int.tryParse(user['id']?.toString() ?? '1') ?? 1;

        await saveUserSession({
          'user_id': userId,
          'username': user['username'] ?? usernameOrEmail,
          'email': user['email'] ?? usernameOrEmail,
          'store_name': user['store_name'] ?? 'My Store',
          'store_address': user['store_address'] ?? '123 Main Street, City',
          'phone': user['phone'] ?? '+63 912 345 6789',
          'role': user['role'] ?? 'Admin',
        });

        return {
          'success': true,
          'message': 'Login successful',
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid username/email or password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Login error: $e',
      };
    }
  }

  /// Registers a new account into SQLite database and sets up active session
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
      final exists = await _db.userExists(username, email);
      if (exists) {
        return {
          'success': false,
          'message': 'Username or Email is already registered',
        };
      }

      final userId = await _db.registerUser({
        'username': username,
        'email': email,
        'password': password,
        'store_name': storeName,
        'store_address': storeAddress,
        'phone': phone,
        'role': role,
      });

      if (userId != null && userId > 0) {
        await saveUserSession({
          'user_id': userId,
          'username': username,
          'email': email,
          'store_name': storeName,
          'store_address': storeAddress,
          'phone': phone,
          'role': role,
        });

        return {
          'success': true,
          'message': 'Account registered successfully',
          'user_id': userId,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to save account to database',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration error: $e',
      };
    }
  }

  /// Saves user profile and login state in SharedPreferences
  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    if (userData['user_id'] != null) {
      final uid = userData['user_id'] is int
          ? userData['user_id'] as int
          : int.tryParse(userData['user_id'].toString()) ?? 1;
      await prefs.setInt('user_id', uid);
    }
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
      await prefs.setString('store_address', userData['store_address'].toString());
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

  /// Updates user profile on SQLite database and in SharedPreferences
  static Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String email,
    required String storeName,
    required String storeAddress,
    required String phone,
    String? originalUsername,
    String? originalEmail,
  }) async {
    try {
      final userId = await getCurrentUserId();
      final success = await _db.updateUserProfile(
        userId: userId,
        username: username,
        email: email,
        storeName: storeName,
        storeAddress: storeAddress,
        phone: phone,
      );

      if (success) {
        await saveUserSession({
          'user_id': userId,
          'username': username,
          'email': email,
          'store_name': storeName,
          'store_address': storeAddress,
          'phone': phone,
        });
        return {
          'success': true,
          'message': 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Update error: $e',
      };
    }
  }

  /// Logs out user and clears active session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('store_name');
    await prefs.remove('store_address');
    await prefs.remove('phone');
    await prefs.remove('role');
  }
}
