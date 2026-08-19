// lib/services/receipt_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReceiptService {
  static Future<String> generateTextReceipt(Map<String, dynamic> orderData) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('=' * 32);
    buffer.writeln('  INVENTORY MANAGEMENT SYSTEM');
    buffer.writeln('  ${'-' * 28}');
    buffer.writeln('  SALES RECEIPT');
    buffer.writeln('=' * 32);
    buffer.writeln();
    
    // Date & Customer
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('Customer: ${orderData['customer_name']}');
    buffer.writeln('-' * 32);
    buffer.writeln();
    
    // Items
    buffer.writeln('Item          Qty  Price   Total');
    buffer.writeln('-' * 32);
    
    for (var item in orderData['items']) {
      final name = item['product_name'].length > 12 
          ? item['product_name'].substring(0, 12) 
          : item['product_name'].padRight(12);
      final qty = item['quantity'].toString().padLeft(3);
      final price = '₱${item['price'].toStringAsFixed(2)}'.padLeft(7);
      final total = '₱${item['total'].toStringAsFixed(2)}'.padLeft(7);
      buffer.writeln('$name $qty $price $total');
    }
    
    buffer.writeln('-' * 32);
    buffer.writeln();
    
    // Totals
    buffer.writeln('${'TOTAL:'.padRight(20)}₱${orderData['total_amount'].toStringAsFixed(2)}');
    buffer.writeln('${'Cash:'.padRight(20)}₱${orderData['cash_received'].toStringAsFixed(2)}');
    buffer.writeln('${'Change:'.padRight(20)}₱${orderData['change'].toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('=' * 32);
    buffer.writeln('  Thank you for your purchase!');
    buffer.writeln('  Visit us again!');
    buffer.writeln('=' * 32);
    buffer.writeln('  --- End of Receipt ---');
    
    return buffer.toString();
  }

  static Future<File> saveReceipt(String receiptText) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/receipt_$timestamp.txt';
    final file = File(filePath);
    await file.writeAsString(receiptText);
    return file;
  }

  static Future<void> printReceipt(String receiptText) async {
    // For printing to a 58mm thermal printer via USB/Bluetooth
    // You would need a package like flutter_thermal_printer
    // For now, we'll save it to a file
    await saveReceipt(receiptText);
    return;
  }
}