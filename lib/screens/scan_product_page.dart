// lib/screens/scan_product_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/product.dart' as product_model;
import '../services/order_item.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class ScanProductPage extends StatefulWidget {
  const ScanProductPage({super.key});

  @override
  State<ScanProductPage> createState() => _ScanProductPageState();
}

class _ScanProductPageState extends State<ScanProductPage> {
  bool isProcessing = false;
  bool isFlashOn = false;
  MobileScannerController? scannerController;
  String? lastScannedBarcode;
  List<OrderItem> cartItems = [];
  double totalAmount = 0.0;

  // Order details
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController cashReceivedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    scannerController?.dispose();
    customerNameController.dispose();
    cashReceivedController.dispose();
    super.dispose();
  }

  void _initializeScanner() {
    scannerController = MobileScannerController(
      formats: [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  Future<void> searchProduct(String barcode) async {
    if (isProcessing || lastScannedBarcode == barcode) return;

    setState(() {
      isProcessing = true;
      lastScannedBarcode = barcode;
    });

    try {
      // Check if product is already in cart
      final existingItem = cartItems.firstWhere(
        (item) => item.product.barcode == barcode,
        orElse: () => OrderItem(product: Product(barcode: '', productName: '', brand: '', category: '', price: 0), quantity: 0),
      );

      if (existingItem.quantity > 0) {
        // Product already in cart, just increase quantity
        setState(() {
          existingItem.quantity++;
          _updateTotal();
          isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${existingItem.product.productName} quantity updated to ${existingItem.quantity}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Fetch product from database
      final product_model.Product? product = await ProductService.getProduct(barcode);

      if (!mounted) return;

      if (product == null) {
        _showErrorDialog(
          'Product Not Found',
          'No product found with barcode: $barcode',
          isWarning: true,
        );
        return;
      }

      // Check stock availability
      if (product.stock <= 0) {
        _showErrorDialog(
          'Out of Stock',
          '${product.productName} is currently out of stock.',
          isWarning: true,
        );
        return;
      }

      // Add product to cart
      setState(() {
        cartItems.add(OrderItem(
          product: Product(
            barcode: product.barcode,
            productName: product.productName,
            brand: product.brand,
            category: product.category,
            price: product.price,
          ),
          quantity: 1,
        ));
        _updateTotal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} added to cart'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error', 'An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              lastScannedBarcode = null;
            });
          }
        });
      }
    }
  }

  void _updateTotal() {
    totalAmount = cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  void _updateQuantity(OrderItem item, int change) {
    setState(() {
      final newQuantity = item.quantity + change;
      if (newQuantity <= 0) {
        cartItems.remove(item);
      } else {
        item.quantity = newQuantity;
      }
      _updateTotal();
    });
  }

  void _removeItem(OrderItem item) {
    setState(() {
      cartItems.remove(item);
      _updateTotal();
    });
  }

  void _clearCart() {
    if (cartItems.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear all items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                cartItems.clear();
                _updateTotal();
                Navigator.pop(context);
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show payment dialog
    await _showPaymentDialog();
  }

  Future<void> _showPaymentDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Amount: ₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cashReceivedController,
                  decoration: const InputDecoration(
                    labelText: 'Cash Received',
                    border: OutlineInputBorder(),
                    prefixText: '₱',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setStateDialog(() {});
                  },
                ),
                const SizedBox(height: 12),
                if (cashReceivedController.text.isNotEmpty)
                  Text(
                    'Change: ₱${_calculateChange().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _calculateChange() >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  customerNameController.clear();
                  cashReceivedController.clear();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final change = _calculateChange();
                  if (change < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Insufficient cash received!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Save order
                  await _saveOrderToDatabase(change);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Complete Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  double _calculateChange() {
    final cashReceived = double.tryParse(cashReceivedController.text) ?? 0;
    return cashReceived - totalAmount;
  }

  Future<void> _saveOrderToDatabase(double change) async {
    try {
      final orderData = {
        'customer_name': customerNameController.text.trim().isEmpty ? 'Walk-in Customer' : customerNameController.text.trim(),
        'items': cartItems.map((item) => item.toMap()).toList(),
        'total_amount': totalAmount,
        'cash_received': double.tryParse(cashReceivedController.text) ?? 0,
        'change': change,
        'order_date': DateTime.now().toIso8601String(),
      };

      final success = await OrderService.saveOrder(orderData);

      if (!mounted) return;

      if (success) {
        // Print receipt
        await _printReceipt(orderData);

        // Clear cart
        setState(() {
          cartItems.clear();
          _updateTotal();
          customerNameController.clear();
          cashReceivedController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved and receipt printed!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorDialog('Error', 'Failed to save order');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to save order: $e');
    }
  }

  Future<void> _printReceipt(Map<String, dynamic> orderData) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            58 * PdfPageFormat.mm,
            200 * PdfPageFormat.mm,
            marginAll: 8 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'INVENTORY SYSTEM',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Sales Receipt',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 19)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Customer: ${orderData['customer_name']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),

                // Items
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),

                // Item list
                for (var item in orderData['items'])
                  pw.Column(
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              item['product_name'],
                              style: const pw.TextStyle(fontSize: 10),
                              maxLines: 2,
                            ),
                          ),
                          pw.Text(
                            item['quantity'].toString(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '₱${item['price'].toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '₱${item['total'].toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 0.5),
                    ],
                  ),

                pw.SizedBox(height: 8),

                // Totals
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.Text(
                      '₱${orderData['total_amount'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Cash:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '₱${orderData['cash_received'].toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Change:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '₱${orderData['change'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for your purchase!',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Visit us again!',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '--- End of Receipt ---',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Print or save PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

    } catch (e) {
      print('Error printing: $e');
      // Fallback: save to file
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
        
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to: ${file.path}'),
            backgroundColor: Colors.blue,
          ),
        );
      } catch (e) {
        print('Error saving receipt: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message, {bool isWarning = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isWarning ? Icons.warning : Icons.error,
              color: isWarning ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    setState(() {
      isFlashOn = !isFlashOn;
    });
    scannerController?.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: isFlashOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Toggle Flash',
          ),
          if (cartItems.isNotEmpty)
            IconButton(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scanner Section
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final barcode = barcodes.first.rawValue;
                    if (barcode == null) return;
                    searchProduct(barcode);
                  },
                ),
                // Scanner Overlay
                _buildScannerOverlay(),
                if (isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                // Manual entry
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter barcode manually...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          searchProduct(value.trim());
                        }
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Scan barcode to add to cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cart Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.deepPurple),
                            const SizedBox(width: 8),
                            Text(
                              'Cart (${cartItems.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Total: ₱${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Cart Items
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Cart is empty',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Scan products to add them here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return _buildCartItem(item);
                            },
                          ),
                  ),
                  // Checkout Button
                  if (cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _saveOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.payment, color: Colors.white),
                          label: const Text(
                            'CHECKOUT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(OrderItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${item.product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Quantity controls
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _updateQuantity(item, -1),
                    icon: const Icon(Icons.remove, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      item.quantity.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _updateQuantity(item, 1),
                    icon: const Icon(Icons.add, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Total and remove
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeItem(item),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      size: MediaQuery.of(context).size,
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final double scanAreaWidth = 280;
    final double scanAreaHeight = 180;
    final double left = (size.width - scanAreaWidth) / 2;
    final double top = (size.height - scanAreaHeight) / 2 - 40;

    final path = Path()
      ..addRect(Rect.fromLTRB(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, left + scanAreaWidth, top + scanAreaHeight),
          const Radius.circular(15),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const double cornerLength = 25;

    // Draw corner markers
    // Top-left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(left + scanAreaWidth - cornerLength, top), Offset(left + scanAreaWidth, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaWidth, top), Offset(left + scanAreaWidth, top + cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(left, top + scanAreaHeight - cornerLength), Offset(left, top + scanAreaHeight), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaHeight), Offset(left + cornerLength, top + scanAreaHeight), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(left + scanAreaWidth - cornerLength, top + scanAreaHeight), Offset(left + scanAreaWidth, top + scanAreaHeight), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaWidth, top + scanAreaHeight - cornerLength), Offset(left + scanAreaWidth, top + scanAreaHeight), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}