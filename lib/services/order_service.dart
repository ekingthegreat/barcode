// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderService {
  static const String baseUrl = 'http://localhost/barcode';
  
  // For Android Emulator
  // static const String baseUrl = 'http://10.0.2.2/barcode';
  
  // For Physical Device
  // static const String baseUrl = 'http://192.168.1.100/barcode';

  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    try {
      final url = Uri.parse('$baseUrl/products/save.php');
      
      print('Saving order to: $url');
      print('Order data: $orderData');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(orderData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('Exception saving order: $e');
      return false;
    }
  }
}