// lib/models/product.dart
class Product {
  final int? id;
  final int? userId;
  final String barcode;
  final String productName;
  final String brand;
  final String category;
  final double price;
  final int stock;
  final String? imageUrl;

  Product({
    this.id,
    this.userId,
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.category,
    required this.price,
    required this.stock,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'barcode': barcode,
      'product_name': productName,
      'brand': brand,
      'category': category,
      'price': price,
      'stock': stock,
      'image_url': imageUrl,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      barcode: map['barcode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      stock: int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
      imageUrl: map['image_url']?.toString(),
    );
  }
}