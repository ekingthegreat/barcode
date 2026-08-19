// lib/screens/scan_product_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../services/order_item.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';
import '../services/receipt_service.dart';
import 'register_product_page.dart';

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
  final TextEditingController manualBarcodeController = TextEditingController();

  Map<String, dynamic>? lastCompletedOrder;

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
    manualBarcodeController.dispose();
    super.dispose();
  }

  double currentZoom = 1.0;

  void _initializeScanner() {
    scannerController = MobileScannerController(
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
      ],
      detectionSpeed: DetectionSpeed.normal,
      autoStart: true,
    );
  }

  void _toggleZoom() {
    if (scannerController == null) return;
    final nextZoom = currentZoom == 1.0 ? 2.0 : 1.0;
    scannerController!.setZoomScale(nextZoom);
    setState(() {
      currentZoom = nextZoom;
    });
  }

  void _navigateToRegisterPage({String? barcode}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterProductPage(
          initialProduct: barcode != null && barcode.isNotEmpty
              ? Product(
                  barcode: barcode,
                  productName: '',
                  brand: '',
                  category: '',
                  price: 0,
                  stock: 0,
                )
              : null,
        ),
      ),
    );

    if (result == true && barcode != null) {
      // Re-search scanned barcode after registration
      searchProduct(barcode);
    }
  }

  Future<void> searchProduct(String barcode) async {
    if (isProcessing || lastScannedBarcode == barcode) return;

    setState(() {
      isProcessing = true;
      lastScannedBarcode = barcode;
    });

    try {
      // Check if product is already in cart
      final existingIndex = cartItems.indexWhere(
        (item) => item.product.barcode == barcode,
      );

      if (existingIndex != -1) {
        // Product already in cart, increase quantity
        setState(() {
          cartItems[existingIndex].quantity++;
          _updateTotal();
          isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${cartItems[existingIndex].product.productName} qty updated to ${cartItems[existingIndex].quantity}',
            ),
            backgroundColor: Colors.deepPurple.shade700,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Fetch product from database
      final Product? product = await ProductService.getProduct(barcode);

      if (!mounted) return;

      if (product == null) {
        _showNotFoundDialog(barcode);
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
          product: product,
          quantity: 1,
        ));
        _updateTotal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${product.productName} added to cart'),
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

  void _showNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Product Not Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No product found for barcode:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                barcode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to register this new product now?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegisterPage(barcode: barcode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Register Product'),
          ),
        ],
      ),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from the cart?'),
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

  double _calculateChange() {
    final cashReceived = double.tryParse(cashReceivedController.text) ?? 0;
    return cashReceived - totalAmount;
  }

  Future<void> _showCheckoutDialog() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty! Scan products first.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool printReceiptAutomatically = true;
    bool isSavingOrder = false;

    // Set default cash received to total amount
    cashReceivedController.text = totalAmount.toStringAsFixed(2);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final change = _calculateChange();
          final isCashValid = change >= 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.point_of_sale,
                    color: Colors.deepPurple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Checkout & Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL PAYABLE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cartItems.length} item(s) in cart',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Name
                  TextField(
                    controller: customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name (Optional)',
                      hintText: 'Walk-in Customer',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.deepPurple.shade700,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cash Received
                  TextField(
                    controller: cashReceivedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cash Received *',
                      prefixText: '₱ ',
                      prefixStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.payments_outlined,
                        color: Colors.deepPurple.shade700,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 8),

                  // Quick cash presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Exact', totalAmount, setStateDialog),
                        const SizedBox(width: 6),
                        _buildPresetChip('+₱50', totalAmount + 50, setStateDialog),
                        const SizedBox(width: 6),
                        _buildPresetChip('+₱100', totalAmount + 100, setStateDialog),
                        const SizedBox(width: 6),
                        _buildPresetChip('+₱500', totalAmount + 500, setStateDialog),
                        const SizedBox(width: 6),
                        _buildPresetChip('+₱1000', totalAmount + 1000, setStateDialog),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Change Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCashValid ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCashValid ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isCashValid ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                        Text(
                          isCashValid
                              ? '₱${change.toStringAsFixed(2)}'
                              : 'Insufficient (₱${change.abs().toStringAsFixed(2)} lacking)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCashValid ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bluetooth Thermal 58mm Print Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: printReceiptAutomatically,
                        activeColor: Colors.deepPurple.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setStateDialog(() {
                            printReceiptAutomatically = val ?? true;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Print 58mm Receipt (Bluetooth / Thermal)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingOrder ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton.icon(
                onPressed: (!isCashValid || isSavingOrder)
                    ? null
                    : () async {
                        setStateDialog(() {
                          isSavingOrder = true;
                        });

                        final orderData = {
                          'customer_name': customerNameController.text.trim().isEmpty
                              ? 'Walk-in Customer'
                              : customerNameController.text.trim(),
                          'items': cartItems.map((item) => item.toMap()).toList(),
                          'total_amount': totalAmount,
                          'cash_received': double.tryParse(cashReceivedController.text) ?? totalAmount,
                          'change': change,
                          'order_date': DateTime.now().toIso8601String(),
                        };

                        // 1. Save order to backend database
                        final saved = await OrderService.saveOrder(orderData);

                        if (!mounted) return;

                        if (saved) {
                          lastCompletedOrder = orderData;

                          // 2. Direct print 58mm receipt (no browser/preview popup)
                          if (printReceiptAutomatically) {
                            await ReceiptService.printDirect(orderData, context: context);
                          }

                          if (!mounted) return;

                          Navigator.pop(context);

                          // Clear cart
                          setState(() {
                            cartItems.clear();
                            _updateTotal();
                            customerNameController.clear();
                            cashReceivedController.clear();
                          });

                          // Show order completion banner
                          _showOrderCompletedDialog(orderData);
                        } else {
                          setStateDialog(() {
                            isSavingOrder = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to save order to server!'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: isSavingOrder
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.print, size: 20),
                label: Text(
                  isSavingOrder ? 'PROCESSING...' : 'PAY & PRINT (58mm)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetChip(String label, double amount, StateSetter setStateDialog) {
    return InkWell(
      onTap: () {
        cashReceivedController.text = amount.toStringAsFixed(2);
        setStateDialog(() {});
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.deepPurple.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.deepPurple.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showOrderCompletedDialog(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ₱${(double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Change: ₱${(double.tryParse(orderData['change']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ReceiptService.printDirect(orderData, context: context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple.shade700,
                      side: BorderSide(color: Colors.deepPurple.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text('Reprint 58mm'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message, {bool isWarning = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.error_outline,
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Scan Product',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Zoom toggle
          IconButton(
            onPressed: _toggleZoom,
            icon: Text(
              '${currentZoom.toStringAsFixed(0)}x',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            tooltip: 'Toggle Zoom (1x / 2x)',
          ),
          // Flash toggle
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: isFlashOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Toggle Flash',
          ),
          // Register Product Button
          IconButton(
            onPressed: () => _navigateToRegisterPage(),
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Register New Product',
          ),
          // Bluetooth / Thermal Printer Setup
          IconButton(
            onPressed: () => ReceiptService.selectPrinter(context),
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Select Bluetooth/Thermal Printer',
          ),
          // Clear cart
          if (cartItems.isNotEmpty)
            IconButton(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Scanner Viewport
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: scannerController,
                  scanWindow: Rect.fromCenter(
                    center: Offset(
                      MediaQuery.of(context).size.width / 2,
                      (MediaQuery.of(context).size.height * 0.35) / 2,
                    ),
                    width: 260,
                    height: 160,
                  ),
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue?.trim();
                    if (raw == null || raw.isEmpty || raw.length < 3) return;
                    searchProduct(raw);
                  },
                ),

                // Overlay Painter
                _buildScannerOverlay(),

                // Processing Spinner
                if (isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // Top Quick Register Pill
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToRegisterPage(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Register Product',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Manual Barcode Input field
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: manualBarcodeController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Enter barcode manually...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.qr_code_scanner, color: Colors.deepPurple.shade700),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.arrow_forward_rounded, color: Colors.deepPurple.shade700),
                          onPressed: () {
                            final code = manualBarcodeController.text.trim();
                            if (code.isNotEmpty) {
                              searchProduct(code);
                              manualBarcodeController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          searchProduct(value.trim());
                          manualBarcodeController.clear();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Cart View
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Cart Header Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.deepPurple.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cart (${cartItems.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₱${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Cart Items List
                  Expanded(
                    child: cartItems.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.qr_code_scanner,
                                      size: 54,
                                      color: Colors.deepPurple.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'No products scanned yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Scan barcodes with camera or enter code manually',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return _buildCartItem(item);
                            },
                          ),
                  ),

                  // Bottom Action Buttons (Checkout + 58mm Thermal Print)
                  if (cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Quick 58mm print button
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.deepPurple.shade200),
                            ),
                            child: IconButton(
                              onPressed: () {
                                final orderPreviewData = {
                                  'customer_name': 'Walk-in Customer',
                                  'items': cartItems.map((item) => item.toMap()).toList(),
                                  'total_amount': totalAmount,
                                  'cash_received': totalAmount,
                                  'change': 0.0,
                                  'order_date': DateTime.now().toIso8601String(),
                                };
                                ReceiptService.printDirect(orderPreviewData, context: context);
                              },
                              icon: Icon(
                                Icons.print_outlined,
                                color: Colors.deepPurple.shade700,
                              ),
                              tooltip: 'Direct Print 58mm Receipt',
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Checkout & Print Button
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _showCheckoutDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.receipt_long, size: 20),
                                label: Text(
                                  'CHECKOUT & PRINT (₱${totalAmount.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Info
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
                const SizedBox(height: 2),
                Text(
                  '₱${item.product.price.toStringAsFixed(2)}  •  ${item.product.barcode}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Quantity stepper
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _updateQuantity(item, -1),
                  icon: const Icon(Icons.remove, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _updateQuantity(item, 1),
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Line Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${item.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              GestureDetector(
                onTap: () => _removeItem(item),
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
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

    final double scanAreaWidth = 260;
    final double scanAreaHeight = 160;
    final double left = (size.width - scanAreaWidth) / 2;
    final double top = (size.height - scanAreaHeight) / 2 - 20;

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

    const double cornerLength = 22;

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