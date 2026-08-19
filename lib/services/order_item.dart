// lib/services/order_item.dart
import '../models/product.dart';

class OrderItem {
  final Product product;
  int quantity;

  OrderItem({
    required this.product,
    required this.quantity,
  });

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'barcode': product.barcode,
      'product_name': product.productName,
      'brand': product.brand,
      'category': product.category,
      'price': product.price,
      'quantity': quantity,
      'total': totalPrice,
    };
  }
}