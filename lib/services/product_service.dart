// lib/services/product_service.dart
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Registers a new product into the local SQLite database
  static Future<bool> registerProduct(Product product) async {
    return await _db.insertProduct(product);
  }

  /// Gets a product by barcode from the local SQLite database
  static Future<Product?> getProduct(String barcode) async {
    return await _db.getProductByBarcode(barcode);
  }

  /// Gets all products from the local SQLite database
  static Future<List<Product>> getAllProducts() async {
    return await _db.getAllProducts();
  }

  /// Updates an existing product in the local SQLite database
  static Future<bool> updateProduct(Product product) async {
    return await _db.updateProduct(product);
  }

  /// Deletes a product from the local SQLite database
  static Future<bool> deleteProduct(String barcode) async {
    return await _db.deleteProduct(barcode);
  }
}