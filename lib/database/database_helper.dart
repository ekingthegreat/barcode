// lib/database/database_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/product.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Initialize FFI for Windows / Linux Desktop support
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (Platform.isWindows || Platform.isLinux) {
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = join(appDocDir.path, 'InventoryApp', filePath);
      final dbDir = Directory(dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
    } else {
      final defaultDatabasesPath = await getDatabasesPath();
      dbPath = join(defaultDatabasesPath, filePath);
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        email $textType UNIQUE,
        password $textType,
        store_name $textNullable,
        store_address $textNullable,
        phone $textNullable,
        role $textNullable DEFAULT 'Admin',
        created_at $textType
      )
    ''');

    // 2. Products Table (User Scoped: unique barcode per user account)
    await db.execute('''
      CREATE TABLE products (
        id $idType,
        user_id $intType DEFAULT 1,
        barcode $textType,
        product_name $textType,
        brand $textNullable DEFAULT '',
        category $textNullable DEFAULT 'General',
        price $realType DEFAULT 0.0,
        stock $intType DEFAULT 0,
        image_url $textNullable,
        created_at $textType,
        updated_at $textNullable,
        UNIQUE(user_id, barcode)
      )
    ''');

    // 3. Orders Table (User Scoped)
    await db.execute('''
      CREATE TABLE orders (
        id $idType,
        user_id $intType DEFAULT 1,
        order_id $textType,
        customer_name $textNullable DEFAULT 'Walk-in Customer',
        total_amount $realType,
        cash_received $realType,
        change_amount $realType,
        order_date $textType,
        created_at $textType,
        UNIQUE(user_id, order_id)
      )
    ''');

    // 4. Order Items Table (User Scoped)
    await db.execute('''
      CREATE TABLE order_items (
        id $idType,
        user_id $intType DEFAULT 1,
        order_id $textType,
        barcode $textNullable,
        product_name $textType,
        brand $textNullable,
        category $textNullable,
        price $realType,
        quantity $intType,
        total $realType
      )
    ''');

    // 5. Initial Seed: Default Admin User
    await db.insert('users', {
      'username': 'admin',
      'email': 'admin@example.com',
      'password': 'admin',
      'store_name': 'My Store',
      'store_address': '123 Main Street, City',
      'phone': '+63 912 345 6789',
      'role': 'Admin',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE order_items ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
    }
  }

  /// Helper to get current user ID from SharedPreferences
  Future<int> _getActiveUserId({int? explicitUserId}) async {
    if (explicitUserId != null) return explicitUserId;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_id') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  // ==========================================
  // USER / AUTH METHODS
  // ==========================================

  Future<Map<String, dynamic>?> authenticateUser({
    required String usernameOrEmail,
    required String password,
  }) async {
    final db = await database;
    final cleanInput = usernameOrEmail.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: '(LOWER(username) = ? OR LOWER(email) = ?) AND password = ?',
      whereArgs: [cleanInput, cleanInput, password],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<bool> userExists(String username, String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(username) = ? OR LOWER(email) = ?',
      whereArgs: [username.trim().toLowerCase(), email.trim().toLowerCase()],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Inserts a new user and returns the new user's ID
  Future<int?> registerUser(Map<String, dynamic> userData) async {
    try {
      final db = await database;
      final row = {
        'username': (userData['username'] ?? '').toString().trim(),
        'email': (userData['email'] ?? '').toString().trim(),
        'password': (userData['password'] ?? '').toString(),
        'store_name': (userData['store_name'] ?? 'My Store').toString().trim(),
        'store_address': (userData['store_address'] ?? '123 Main Street, City').toString().trim(),
        'phone': (userData['phone'] ?? '+63 912 345 6789').toString().trim(),
        'role': (userData['role'] ?? 'Admin').toString().trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final id = await db.insert(
        'users',
        row,
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return id;
    } catch (e) {
      debugPrint('DatabaseHelper.registerUser error: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile({
    required int userId,
    required String username,
    required String email,
    required String storeName,
    required String storeAddress,
    required String phone,
  }) async {
    try {
      final db = await database;

      final count = await db.update(
        'users',
        {
          'username': username.trim(),
          'email': email.trim(),
          'store_name': storeName.trim(),
          'store_address': storeAddress.trim(),
          'phone': phone.trim(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return count > 0;
    } catch (e) {
      debugPrint('DatabaseHelper.updateUserProfile error: $e');
      return false;
    }
  }

  // ==========================================
  // PRODUCT METHODS (ACCOUNT ISOLATED)
  // ==========================================

  Future<bool> insertProduct(Product product, {int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId ?? product.userId);
      final now = DateTime.now().toIso8601String();

      await db.insert(
        'products',
        {
          'user_id': uId,
          'barcode': product.barcode.trim(),
          'product_name': product.productName.trim(),
          'brand': product.brand.trim(),
          'category': product.category.trim().isNotEmpty ? product.category.trim() : 'General',
          'price': product.price,
          'stock': product.stock,
          'image_url': product.imageUrl,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('DatabaseHelper.insertProduct error: $e');
      return false;
    }
  }

  Future<Product?> getProductByBarcode(String barcode, {int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      final maps = await db.query(
        'products',
        where: 'barcode = ? AND user_id = ?',
        whereArgs: [barcode.trim(), uId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('DatabaseHelper.getProductByBarcode error: $e');
      return null;
    }
  }

  Future<List<Product>> getAllProducts({int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      final results = await db.query(
        'products',
        where: 'user_id = ?',
        whereArgs: [uId],
        orderBy: 'id DESC',
      );
      return results.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DatabaseHelper.getAllProducts error: $e');
      return [];
    }
  }

  Future<bool> updateProduct(Product product, {int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId ?? product.userId);

      final count = await db.update(
        'products',
        {
          'product_name': product.productName.trim(),
          'brand': product.brand.trim(),
          'category': product.category.trim().isNotEmpty ? product.category.trim() : 'General',
          'price': product.price,
          'stock': product.stock,
          'image_url': product.imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'barcode = ? AND user_id = ?',
        whereArgs: [product.barcode.trim(), uId],
      );
      return count > 0;
    } catch (e) {
      debugPrint('DatabaseHelper.updateProduct error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String barcode, {int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      final count = await db.delete(
        'products',
        where: 'barcode = ? AND user_id = ?',
        whereArgs: [barcode.trim(), uId],
      );
      return count > 0;
    } catch (e) {
      debugPrint('DatabaseHelper.deleteProduct error: $e');
      return false;
    }
  }

  // ==========================================
  // ORDER & TRANSACTION METHODS (ACCOUNT ISOLATED)
  // ==========================================

  Future<bool> saveOrder(Map<String, dynamic> orderData, {int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      return await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        final orderId = orderData['order_id']?.toString() ??
            orderData['id']?.toString() ??
            'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

        final customerName = (orderData['customer_name']?.toString() ?? '').trim().isNotEmpty
            ? orderData['customer_name'].toString().trim()
            : 'Walk-in Customer';

        final totalAmount = double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0.0;
        final cashReceived = double.tryParse(orderData['cash_received']?.toString() ?? '$totalAmount') ?? totalAmount;
        final changeAmount = double.tryParse(
              (orderData['change'] ?? orderData['change_amount'])?.toString() ?? '0',
            ) ??
            0.0;
        final orderDate = orderData['order_date']?.toString() ?? now;

        // 1. Insert Order
        await txn.insert('orders', {
          'user_id': uId,
          'order_id': orderId,
          'customer_name': customerName,
          'total_amount': totalAmount,
          'cash_received': cashReceived,
          'change_amount': changeAmount,
          'order_date': orderDate,
          'created_at': now,
        });

        // 2. Insert Order Items & Deduct Stock
        final items = (orderData['items'] as List<dynamic>?) ?? [];
        for (var rawItem in items) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final barcode = item['barcode']?.toString() ?? '';
          final productName = (item['product_name'] ?? 'Product').toString();
          final brand = item['brand']?.toString() ?? '';
          final category = item['category']?.toString() ?? '';
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
          final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
          final total = double.tryParse(item['total']?.toString() ?? '${price * quantity}') ?? (price * quantity);

          await txn.insert('order_items', {
            'user_id': uId,
            'order_id': orderId,
            'barcode': barcode,
            'product_name': productName,
            'brand': brand,
            'category': category,
            'price': price,
            'quantity': quantity,
            'total': total,
          });

          // Deduct stock from products for this user only
          if (barcode.isNotEmpty) {
            await txn.rawUpdate('''
              UPDATE products 
              SET stock = CASE WHEN stock >= ? THEN stock - ? ELSE 0 END,
                  updated_at = ?
              WHERE barcode = ? AND user_id = ?
            ''', [quantity, quantity, now, barcode, uId]);
          }
        }

        return true;
      });
    } catch (e) {
      debugPrint('DatabaseHelper.saveOrder error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrders({int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      final orderRows = await db.query(
        'orders',
        where: 'user_id = ?',
        whereArgs: [uId],
        orderBy: 'id DESC',
      );

      final List<Map<String, dynamic>> orders = [];

      for (var orderRow in orderRows) {
        final orderId = orderRow['order_id']?.toString() ?? orderRow['id']?.toString() ?? '';
        final itemRows = await db.query(
          'order_items',
          where: 'order_id = ? AND user_id = ?',
          whereArgs: [orderId, uId],
        );

        final itemsList = itemRows.map((item) => {
          'id': item['id'],
          'user_id': item['user_id'],
          'order_id': item['order_id'],
          'barcode': item['barcode'],
          'product_name': item['product_name'],
          'brand': item['brand'],
          'category': item['category'],
          'price': item['price'],
          'quantity': item['quantity'],
          'total': item['total'],
        }).toList();

        orders.add({
          'id': orderRow['id'],
          'user_id': orderRow['user_id'],
          'order_id': orderRow['order_id'],
          'customer_name': orderRow['customer_name'],
          'total_amount': orderRow['total_amount'],
          'cash_received': orderRow['cash_received'],
          'change': orderRow['change_amount'],
          'change_amount': orderRow['change_amount'],
          'order_date': orderRow['order_date'],
          'created_at': orderRow['created_at'],
          'items': itemsList,
        });
      }

      return orders;
    } catch (e) {
      debugPrint('DatabaseHelper.getAllOrders error: $e');
      return [];
    }
  }

  // ==========================================
  // DASHBOARD & STATS (ACCOUNT ISOLATED)
  // ==========================================

  Future<Map<String, dynamic>> getDashboardStatsData({int? userId}) async {
    try {
      final db = await database;
      final uId = await _getActiveUserId(explicitUserId: userId);

      // 1. Total Products count for active account
      final productCountResult = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products WHERE user_id = ?', [uId]),
      ) ?? 0;

      // 2. Orders summary for active account
      final orders = await getAllOrders(userId: uId);
      final products = await getAllProducts(userId: uId);

      final totalProducts = productCountResult;
      final totalOrders = orders.length;

      double totalSales = 0.0;
      double todaySales = 0.0;
      int todayOrders = 0;
      final Set<String> customers = {};
      final now = DateTime.now();

      final List<Map<String, dynamic>> activities = [];

      for (final order in orders) {
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;

        final rawDate = order['order_date'] ?? order['created_at'];
        final date = DateTime.tryParse(rawDate?.toString() ?? '') ?? now;

        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          todaySales += amount;
          todayOrders++;
        }

        final cust = (order['customer_name']?.toString() ?? '').trim();
        if (cust.isNotEmpty && cust.toLowerCase() != 'walk-in customer') {
          customers.add(cust.toLowerCase());
        }

        activities.add({
          'id': 'order_${order['order_id'] ?? order['id'] ?? ''}',
          'type': 'transaction',
          'title': 'Transaction Completed',
          'subtitle': 'Order #${order['order_id'] ?? order['id'] ?? ''} • ${cust.isNotEmpty ? cust : 'Walk-in Customer'} (₱${amount.toStringAsFixed(2)})',
          'timestamp': rawDate?.toString() ?? date.toIso8601String(),
          'color': 'orange',
          'icon': 'receipt',
        });
      }

      for (final p in products) {
        activities.add({
          'id': 'product_${p.barcode}',
          'type': 'product',
          'title': 'Product in Inventory',
          'subtitle': '${p.productName}${p.brand.isNotEmpty ? ' (${p.brand})' : ''} • ₱${p.price.toStringAsFixed(2)} (Stock: ${p.stock})',
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

      return {
        'total_products': totalProducts,
        'total_orders': totalOrders,
        'total_sales': totalSales,
        'today_sales': todaySales,
        'today_orders': todayOrders,
        'unique_customers': customers.isEmpty && orders.isNotEmpty ? 1 : customers.length,
        'recent_activities': activities.take(6).toList(),
      };
    } catch (e) {
      debugPrint('DatabaseHelper.getDashboardStatsData error: $e');
      return {
        'total_products': 0,
        'total_orders': 0,
        'total_sales': 0.0,
        'today_sales': 0.0,
        'today_orders': 0,
        'unique_customers': 0,
        'recent_activities': [],
      };
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
