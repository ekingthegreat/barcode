// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../services/sound_service.dart';
import '../widgets/app_logo.dart';

class RegisterProductPage extends StatefulWidget {
  final Product? initialProduct;

  const RegisterProductPage({
    super.key,
    this.initialProduct,
  });

  @override
  State<RegisterProductPage> createState() => _RegisterProductPageState();
}

class _RegisterProductPageState extends State<RegisterProductPage> {
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

    final isEditing = widget.initialProduct != null;
    try {
      final success = isEditing
          ? await ProductService.updateProduct(product)
          : await ProductService.registerProduct(product);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? '✓ Product updated successfully'
                  : '✓ Product registered successfully',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (isEditing) {
          Navigator.pop(context, true);
        } else {
          barcodeController.clear();
          nameController.clear();
          brandController.clear();
          categoryController.clear();
          priceController.clear();
          stockController.clear();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Failed to update product' : 'Failed to register product',
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

  bool isTorchOn = false;
  double currentZoom = 1.0;

  void startBarcodeScan() {
    setState(() {
      isScanning = true;
      isTorchOn = false;
      currentZoom = 1.0;
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
    });
  }

  void stopBarcodeScan() {
    setState(() {
      isScanning = false;
      isTorchOn = false;
      scannerController?.dispose();
      scannerController = null;
    });
  }

  void _toggleTorch() {
    if (scannerController == null) return;
    scannerController!.toggleTorch();
    setState(() {
      isTorchOn = !isTorchOn;
    });
  }

  void _toggleZoom() {
    if (scannerController == null) return;
    final nextZoom = currentZoom == 1.0 ? 2.0 : 1.0;
    scannerController!.setZoomScale(nextZoom);
    setState(() {
      currentZoom = nextZoom;
    });
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    
    // Ignore invalid/empty reads
    if (raw == null || raw.isEmpty || raw.length < 3) return;

    if (mounted) {
      SoundService.playSuccessBeep();
      barcodeController.text = raw;
      stopBarcodeScan();
      FocusScope.of(context).requestFocus(nameFocus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Barcode scanned: $raw'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget buildBarcodeSection() {
    if (isScanning) {
      final screenWidth = MediaQuery.of(context).size.width;
      const double scanAreaWidth = 260;
      const double scanAreaHeight = 160;
      final scanWindow = Rect.fromCenter(
        center: Offset(screenWidth / 2, 150),
        width: scanAreaWidth,
        height: scanAreaHeight,
      );

      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            MobileScanner(
              controller: scannerController!,
              scanWindow: scanWindow,
              onDetect: onBarcodeDetected,
            ),
            // Scanner overlay with corner markers
            CustomPaint(
              painter: RegisterScannerOverlayPainter(),
              size: Size(screenWidth, 300),
            ),
            // Top controls: Flash, Zoom, Close
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Torch toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: _toggleTorch,
                          icon: Icon(
                            isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: isTorchOn ? Colors.yellow : Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Toggle Flash',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Zoom toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: _toggleZoom,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            '${currentZoom.toStringAsFixed(0)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: stopBarcodeScan,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: 'Close Camera',
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'Center barcode inside the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black),
                    ],
                  ),
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
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: startBarcodeScan,
            icon: Icon(
              Icons.qr_code_scanner,
              color: Colors.deepPurple.shade700,
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
            borderSide: BorderSide(
              color: Colors.deepPurple.shade700,
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
          // Header matching ScanProductPage style
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade700,
                  Colors.deepPurple.shade500,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 46),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialProduct != null ? 'Edit Product' : 'Register Product',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.initialProduct != null ? 'Update product details' : 'Add new product to inventory',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 26,
                    ),
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barcode section
                      buildBarcodeSection(),
                      if (!isScanning) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Or enter product details manually',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
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
                      // Register button matching ScanProductPage style
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: loading || isScanning ? null : registerProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, size: 24),
                          label: loading
                              ? Text(
                                  widget.initialProduct != null ? 'UPDATING...' : 'REGISTERING...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                )
                              : Text(
                                  widget.initialProduct != null ? 'UPDATE PRODUCT' : 'REGISTER PRODUCT',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      final p = widget.initialProduct!;
      barcodeController.text = p.barcode;
      nameController.text = p.productName;
      brandController.text = p.brand;
      categoryController.text = p.category;
      priceController.text = p.price > 0 ? p.price.toString() : '';
      stockController.text = p.stock.toString();
    }
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

// Scanner overlay painter matching ScanProductPage style
class RegisterScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final double scanAreaWidth = 220;
    final double scanAreaHeight = 200;
    final double left = (size.width - scanAreaWidth) / 2;
    final double top = (size.height - scanAreaHeight) / 2;

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