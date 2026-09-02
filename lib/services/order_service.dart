// lib/services/order_service.dart
import '../database/database_helper.dart';

class OrderService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Saves an order and its items into SQLite, updating product inventory stock atomically
  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    return await _db.saveOrder(orderData);
  }

  /// Fetches all completed orders and their line items from SQLite
  static Future<List<Map<String, dynamic>>> getAllOrders() async {
    return await _db.getAllOrders();
  }
}