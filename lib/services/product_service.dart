import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductService {

  // Android emulator
  static const String baseUrl =
      'http://192.168.1.180/barcode/products';

  // If using a physical Android phone,
  // replace 10.0.2.2 with your computer's
  // local IP address.

  static Future<bool> registerProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          product.toMap(),
        ),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<Product?> getProduct(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get.php?barcode=$barcode',
        ),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['product'] != null) {
        return Product.fromMap(
          data['product'],
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Product>> getAllProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_all.php'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['products'] is List) {
          return (data['products'] as List)
              .map((p) => Product.fromMap(p as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          product.toMap(),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteProduct(String barcode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'barcode': barcode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}