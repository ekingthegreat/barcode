// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderService {
  static const String baseUrl = 'http://192.168.1.180/barcode';

  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    try {
      final url = Uri.parse('$baseUrl/products/save.php');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      final url = Uri.parse('$baseUrl/products/get_orders.php');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['orders'] is List) {
          return List<Map<String, dynamic>>.from(data['orders']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}