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

  static Future<bool> registerProduct(
      Product product) async {

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
  }

  static Future<Product?> getProduct(
      String barcode) async {

    final response = await http.get(
      Uri.parse(
        '$baseUrl/get.php?barcode=$barcode',
      ),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {

      return Product.fromMap(
        data['product'],
      );
    }

    return null;
  }
}