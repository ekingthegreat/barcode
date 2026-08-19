// lib/services/stats_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'order_service.dart';
import 'product_service.dart';

class DashboardStats {
  final int totalProducts;
  final int totalOrders;
  final double totalSales;
  final double todaySales;
  final int todayOrders;
  final int uniqueCustomers;
  final List<Map<String, dynamic>> recentActivities;

  DashboardStats({
    required this.totalProducts,
    required this.totalOrders,
    required this.totalSales,
    required this.todaySales,
    required this.todayOrders,
    required this.uniqueCustomers,
    required this.recentActivities,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalProducts: 0,
      totalOrders: 0,
      totalSales: 0.0,
      todaySales: 0.0,
      todayOrders: 0,
      uniqueCustomers: 0,
      recentActivities: [],
    );
  }
}

class StatsService {
  static const String statsUrl = ApiConfig.statsUrl;

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  /// Fetches statistics directly from backend or computes fallback
  static Future<DashboardStats> getStats() async {
    try {
      final response = await http
          .get(
            Uri.parse(statsUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['stats'] is Map) {
          final statsMap = data['stats'] as Map<String, dynamic>;
          final rawActivities = data['recent_activities'] as List? ?? [];
          final activities = rawActivities
              .map((a) => Map<String, dynamic>.from(a as Map))
              .toList();

          return DashboardStats(
            totalProducts: _toInt(statsMap['total_products']),
            totalOrders: _toInt(statsMap['total_orders']),
            totalSales: _toDouble(statsMap['total_sales']),
            todaySales: _toDouble(statsMap['today_sales']),
            todayOrders: _toInt(statsMap['today_orders']),
            uniqueCustomers: _toInt(statsMap['unique_customers']),
            recentActivities: activities,
          );
        }
      }
    } catch (_) {
      // Backend stats endpoint unreachable, use fallback calculation
    }

    return await _computeFallbackStats();
  }

  /// Fallback calculation from product and order lists
  static Future<DashboardStats> _computeFallbackStats() async {
    try {
      final productsFuture = ProductService.getAllProducts();
      final ordersFuture = OrderService.getAllOrders();

      final results = await Future.wait([productsFuture, ordersFuture]);
      final products = results[0] as List;
      final orders = results[1] as List<Map<String, dynamic>>;

      final totalProducts = products.length;
      final totalOrders = orders.length;

      double totalSales = 0.0;
      double todaySales = 0.0;
      int todayOrders = 0;
      final Set<String> customers = {};
      final now = DateTime.now();

      final List<Map<String, dynamic>> activities = [];

      for (final order in orders) {
        final amount = _toDouble(order['total_amount']);
        totalSales += amount;

        final rawDate = order['order_date'] ?? order['created_at'];
        final date = DateTime.tryParse(rawDate?.toString() ?? '') ?? now;

        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          todaySales += amount;
          todayOrders++;
        }

        final cust = (order['customer_name']?.toString() ?? '').trim();
        if (cust.isNotEmpty) {
          customers.add(cust.toLowerCase());
        }

        activities.add({
          'id': 'order_${order['id'] ?? order['order_id'] ?? ''}',
          'type': 'transaction',
          'title': 'Transaction Completed',
          'subtitle': 'Order #${order['id'] ?? ''} • ${cust.isNotEmpty ? cust : 'Walk-in Customer'} (₱${amount.toStringAsFixed(2)})',
          'timestamp': rawDate?.toString() ?? date.toIso8601String(),
          'color': 'orange',
          'icon': 'receipt',
        });
      }

      for (final p in products) {
        activities.add({
          'id': 'product_${p.barcode}',
          'type': 'product',
          'title': 'Product Added',
          'subtitle': '${p.productName}${p.brand.isNotEmpty ? ' (${p.brand})' : ''} • ₱${p.price.toStringAsFixed(2)}',
          'timestamp': DateTime.now().toIso8601String(),
          'color': 'green',
          'icon': 'inventory',
        });
      }

      // Sort activities by timestamp descending
      activities.sort((a, b) {
        final dateA = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      return DashboardStats(
        totalProducts: totalProducts,
        totalOrders: totalOrders,
        totalSales: totalSales,
        todaySales: todaySales,
        todayOrders: todayOrders,
        uniqueCustomers: customers.isEmpty && orders.isNotEmpty ? 1 : customers.length,
        recentActivities: activities.take(6).toList(),
      );
    } catch (_) {
      return DashboardStats.empty();
    }
  }
}
