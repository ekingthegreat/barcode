// lib/services/stats_service.dart
import '../database/database_helper.dart';

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
  static final DatabaseHelper _db = DatabaseHelper.instance;

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

  /// Fetches real-time dashboard statistics directly from the local SQLite database
  static Future<DashboardStats> getStats() async {
    try {
      final data = await _db.getDashboardStatsData();

      final rawActivities = data['recent_activities'] as List? ?? [];
      final activities = rawActivities
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();

      return DashboardStats(
        totalProducts: _toInt(data['total_products']),
        totalOrders: _toInt(data['total_orders']),
        totalSales: _toDouble(data['total_sales']),
        todaySales: _toDouble(data['today_sales']),
        todayOrders: _toInt(data['today_orders']),
        uniqueCustomers: _toInt(data['unique_customers']),
        recentActivities: activities,
      );
    } catch (_) {
      return DashboardStats.empty();
    }
  }
}
