// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class RegisterProductPage extends StatefulWidget {
  const RegisterProductPage({
    super.key,
  });

  @override
  State<RegisterProductPage> createState() =>
      _RegisterProductPageState();
}

class _RegisterProductPageState
    extends State<RegisterProductPage> {
  final barcodeController = TextEditingController();
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();

  // FocusNodes for better focus management
  final barcodeFocus = FocusNode();
  final nameFocus = FocusNode();
  final brandFocus = FocusNode();
  final categoryFocus = FocusNode();
  final priceFocus = FocusNode();
  final stockFocus = FocusNode();

  bool loading = false;
  bool isScanning = false;
  MobileScannerController? scannerController;

  Future<void> registerProduct() async {
    // Unfocus any active text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    if (barcodeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Barcode and product name are required',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final product = Product(
      barcode: barcodeController.text.trim(),
      productName: nameController.text.trim(),
      brand: brandController.text.trim(),
      category: categoryController.text.trim(),
      price: double.tryParse(priceController.text) ?? 0,
      stock: int.tryParse(stockController.text) ?? 0,
    );

    try {
      final success = await ProductService.registerProduct(product);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✓ Product registered successfully',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        barcodeController.clear();
        nameController.clear();
        brandController.clear();
        categoryController.clear();
        priceController.clear();
        stockController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to register product',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void startBarcodeScan() {
    setState(() {
      isScanning = true;
      scannerController = MobileScannerController(
        formats: [BarcodeFormat.all],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
  }

  void stopBarcodeScan() {
    setState(() {
      isScanning = false;
      scannerController?.dispose();
      scannerController = null;
    });
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null && mounted) {
      barcodeController.text = barcode.rawValue!;
      stopBarcodeScan();
      FocusScope.of(context).requestFocus(nameFocus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode scanned successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget buildBarcodeSection() {
    if (isScanning) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            MobileScanner(
              controller: scannerController!,
              onDetect: onBarcodeDetected,
            ),
            // Scanner overlay
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Align barcode here',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: stopBarcodeScan,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: input(
            'Barcode *',
            barcodeController,
            barcodeFocus,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: startBarcodeScan,
            icon: Icon(
              Icons.qr_code_scanner,
              color: Colors.blue.shade700,
              size: 30,
            ),
            tooltip: 'Scan Barcode',
          ),
        ),
      ],
    );
  }

  Widget input(
    String label,
    TextEditingController controller,
    FocusNode focusNode, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        autofocus: false,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 16),
        onSubmitted: (_) {
          if (focusNode == barcodeFocus) {
            FocusScope.of(context).requestFocus(nameFocus);
          } else if (focusNode == nameFocus) {
            FocusScope.of(context).requestFocus(brandFocus);
          } else if (focusNode == brandFocus) {
            FocusScope.of(context).requestFocus(categoryFocus);
          } else if (focusNode == categoryFocus) {
            FocusScope.of(context).requestFocus(priceFocus);
          } else if (focusNode == priceFocus) {
            FocusScope.of(context).requestFocus(stockFocus);
          } else if (focusNode == stockFocus) {
            registerProduct();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 2.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with red gradient
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFC62828), // Dark red
                  Color(0xFFE53935), // Bright red
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: Color(0xFFC62828),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Add new product to inventory',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isScanning) return;
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barcode section
                    buildBarcodeSection(),
                    if (!isScanning) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Or enter product details manually',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    // Form fields
                    input(
                      'Product Name *',
                      nameController,
                      nameFocus,
                    ),
                    input(
                      'Brand',
                      brandController,
                      brandFocus,
                    ),
                    input(
                      'Category',
                      categoryController,
                      categoryFocus,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: input(
                            'Price',
                            priceController,
                            priceFocus,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: input(
                            'Stock',
                            stockController,
                            stockFocus,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Register button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFC62828),
                            Color(0xFFE53935),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: loading || isScanning ? null : registerProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'REGISTER PRODUCT',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Management System',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'v1.0.0 • All rights reserved',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.store,
                        color: Colors.white54,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'My Store',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    barcodeController.dispose();
    nameController.dispose();
    brandController.dispose();
    categoryController.dispose();
    priceController.dispose();
    stockController.dispose();

    barcodeFocus.dispose();
    nameFocus.dispose();
    brandFocus.dispose();
    categoryFocus.dispose();
    priceFocus.dispose();
    stockFocus.dispose();

    scannerController?.dispose();
    super.dispose();
  }
}