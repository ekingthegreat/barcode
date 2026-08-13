// lib/models/order_item.dart

class Product {
  final String barcode;
  final String productName;
  final String brand;
  final String category;
  final double price;

  Product({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.category,
    required this.price,
  });
}

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