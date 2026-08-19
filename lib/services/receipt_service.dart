// lib/services/receipt_service.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptService {
  /// 58mm Thermal paper format (58mm width, continuous roll height)
  static final PdfPageFormat format58mm = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 2 * PdfPageFormat.mm,
  );

  /// Keys for storing selected default printer
  static const String _prefPrinterName = 'selected_printer_name';
  static const String _prefPrinterUrl = 'selected_printer_url';

  /// Custom in-app dialog to list, select, and test paired Bluetooth/Thermal printers
  static Future<Printer?> selectPrinter(BuildContext context) async {
    return showDialog<Printer>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const _PrinterSelectionDialog();
      },
    );
  }

  /// Gets the currently saved default printer
  static Future<Printer?> getSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_prefPrinterName);
      final savedUrl = prefs.getString(_prefPrinterUrl);

      if (savedName == null && savedUrl == null) {
        return null;
      }

      final printers = await Printing.listPrinters();
      for (var p in printers) {
        if (savedUrl != null && p.url == savedUrl) {
          return p;
        }
        if (savedName != null && p.name == savedName) {
          return p;
        }
      }

      // If exact match not found but printers exist, return first matching name
      if (printers.isNotEmpty && savedName != null) {
        try {
          return printers.firstWhere(
            (p) => p.name.toLowerCase().contains(savedName.toLowerCase()),
          );
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// Gets the name of the saved printer for UI display
  static Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefPrinterName);
  }

  /// Clears saved printer
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPrinterName);
    await prefs.remove(_prefPrinterUrl);
  }

  /// Direct Silent Printing (prints directly to selected Bluetooth printer if available,
  /// or falls back to system print layout)
  static Future<bool> printDirect(
    Map<String, dynamic> orderData, {
    BuildContext? context,
  }) async {
    try {
      final pdfBytes = await generate58mmPdf(orderData);

      // Check if we have a saved printer
      final Printer? targetPrinter = await getSavedPrinter();

      if (targetPrinter != null) {
        try {
          // Direct silent print to the selected Bluetooth / Thermal printer
          final success = await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
            format: format58mm,
          );
          if (success) return true;
        } catch (_) {
          // If direct print fails on this device, fall back to layoutPdf
        }
      }

      // Standard printing flow
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        format: format58mm,
      );
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Generates a PDF document formatted specifically for 58mm thermal printers
  static Future<Uint8List> generate58mmPdf(
    Map<String, dynamic> orderData, {
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? cashierName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sName = storeName ?? prefs.getString('store_name') ?? 'INVENTORY SYSTEM';
    final sAddress = storeAddress ?? prefs.getString('store_address') ?? '123 Main Street, City';
    final sPhone = storePhone ?? prefs.getString('phone') ?? '+63 912 345 6789';
    final cashier = cashierName ?? prefs.getString('username') ?? 'Cashier';

    final pdf = pw.Document();

    final items = (orderData['items'] as List<dynamic>?) ?? [];
    final totalAmount = double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0.0;
    final cashReceived = double.tryParse(orderData['cash_received']?.toString() ?? '0') ?? 0.0;
    final change = double.tryParse(orderData['change']?.toString() ?? '0') ?? 0.0;
    final customerName = orderData['customer_name']?.toString() ?? 'Walk-in Customer';
    final orderDate = orderData['order_date']?.toString() ?? DateTime.now().toString().substring(0, 19);
    final orderId = orderData['order_id'] ?? orderData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    pdf.addPage(
      pw.Page(
        pageFormat: format58mm,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Store Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        sName.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        sAddress,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                      pw.Text(
                        'Tel: $sPhone',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '*** OFFICIAL RECEIPT ***',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 3),
                _buildDottedLine(),
                pw.SizedBox(height: 3),

                // Order Meta Info
                _buildMetaRow('Receipt #:', 'INV-$orderId'),
                _buildMetaRow('Date:', orderDate.length > 19 ? orderDate.substring(0, 19) : orderDate),
                _buildMetaRow('Cashier:', cashier),
                _buildMetaRow('Customer:', customerName),

                pw.SizedBox(height: 3),
                _buildDottedLine(),
                pw.SizedBox(height: 3),

                // Table Header
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'ITEM',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'PRICE',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'TOTAL',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 2),
                _buildDottedLine(),
                pw.SizedBox(height: 3),

                // Item Rows
                for (var item in items)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['product_name'] ?? 'Product',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                          maxLines: 2,
                        ),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                item['barcode'] != null && item['barcode'].toString().isNotEmpty
                                    ? '#${item['barcode']}'
                                    : '',
                                style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                '${item['quantity'] ?? 1}x',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 6.5),
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                '₱${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 6.5),
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                '₱${(double.tryParse(item['total']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 3),
                _buildDottedLine(),
                pw.SizedBox(height: 3),

                // Payment Summary
                _buildSummaryRow('TOTAL AMOUNT:', '₱${totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 9),
                pw.SizedBox(height: 1),
                _buildSummaryRow('Cash Received:', '₱${cashReceived.toStringAsFixed(2)}', fontSize: 7),
                _buildSummaryRow('Change:', '₱${change.toStringAsFixed(2)}', isBold: true, fontSize: 7.5),

                pw.SizedBox(height: 3),
                _buildDottedLine(),
                pw.SizedBox(height: 5),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for your business!',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Please come again',
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '--- 58mm Thermal Receipt ---',
                        style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildDottedLine() {
    return pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      maxLines: 1,
      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey800),
    );
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 7}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Sends 58mm PDF receipt to system print layout (preview mode)
  static Future<bool> printReceipt58mm(Map<String, dynamic> orderData) async {
    try {
      final pdfBytes = await generate58mmPdf(orderData);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
        format: format58mm,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates plain text receipt for serial/raw bluetooth ESC/POS streams
  static Future<String> generateTextReceipt(Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    final sName = prefs.getString('store_name') ?? 'INVENTORY SYSTEM';
    final sAddress = prefs.getString('store_address') ?? '123 Main Street, City';
    final sPhone = prefs.getString('phone') ?? '+63 912 345 6789';

    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('=' * 32);
    buffer.writeln(sName.center(32));
    buffer.writeln(sAddress.center(32));
    buffer.writeln('Tel: $sPhone'.center(32));
    buffer.writeln('-' * 32);
    buffer.writeln('SALES RECEIPT'.center(32));
    buffer.writeln('=' * 32);
    buffer.writeln();
    
    // Date & Customer
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('Customer: ${orderData['customer_name'] ?? 'Walk-in'}');
    buffer.writeln('-' * 32);
    buffer.writeln();
    
    // Items
    buffer.writeln('Item          Qty  Price   Total');
    buffer.writeln('-' * 32);
    
    final items = orderData['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final name = (item['product_name'] ?? '').length > 12 
          ? (item['product_name'] ?? '').substring(0, 12) 
          : (item['product_name'] ?? '').padRight(12);
      final qty = (item['quantity'] ?? 1).toString().padLeft(3);
      final price = '₱${(double.tryParse(item['price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'.padLeft(7);
      final total = '₱${(double.tryParse(item['total']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'.padLeft(7);
      buffer.writeln('$name $qty $price $total');
    }
    
    buffer.writeln('-' * 32);
    buffer.writeln();
    
    // Totals
    final total = double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0;
    final cash = double.tryParse(orderData['cash_received']?.toString() ?? '0') ?? 0;
    final change = double.tryParse(orderData['change']?.toString() ?? '0') ?? 0;

    buffer.writeln('${'TOTAL:'.padRight(20)}₱${total.toStringAsFixed(2)}');
    buffer.writeln('${'Cash:'.padRight(20)}₱${cash.toStringAsFixed(2)}');
    buffer.writeln('${'Change:'.padRight(20)}₱${change.toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('=' * 32);
    buffer.writeln('Thank you for your purchase!'.center(32));
    buffer.writeln('Visit us again!'.center(32));
    buffer.writeln('=' * 32);
    
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
}

/// Custom in-app dialog widget for managing and selecting Bluetooth & Thermal Printers
class _PrinterSelectionDialog extends StatefulWidget {
  const _PrinterSelectionDialog();

  @override
  State<_PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<_PrinterSelectionDialog> {
  List<Printer> _printers = [];
  bool _isLoading = true;
  String? _savedPrinterName;
  Printer? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final savedName = await ReceiptService.getSavedPrinterName();
      final list = await Printing.listPrinters();

      Printer? matched;
      if (savedName != null && list.isNotEmpty) {
        matched = list.firstWhere(
          (p) => p.name == savedName,
          orElse: () => list.first,
        );
      }

      if (mounted) {
        setState(() {
          _printers = list;
          _savedPrinterName = savedName;
          _selectedPrinter = matched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _printers = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAndSelectPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ReceiptService._prefPrinterName, printer.name);
    await prefs.setString(ReceiptService._prefPrinterUrl, printer.url);

    setState(() {
      _savedPrinterName = printer.name;
      _selectedPrinter = printer;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved printer: ${printer.name}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, printer);
    }
  }

  Future<void> _testPrint(Printer? printer) async {
    final testData = {
      'customer_name': 'Test Print',
      'items': [
        {
          'product_name': '58mm Thermal Test',
          'quantity': 1,
          'price': 1.00,
          'total': 1.00,
        }
      ],
      'total_amount': 1.00,
      'cash_received': 1.00,
      'change': 0.00,
      'order_date': DateTime.now().toIso8601String(),
    };

    if (printer != null) {
      try {
        final pdfBytes = await ReceiptService.generate58mmPdf(testData);
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) async => pdfBytes,
          name: 'test_receipt',
          format: ReceiptService.format58mm,
        );
      } catch (_) {
        await ReceiptService.printReceipt58mm(testData);
      }
    } else {
      await ReceiptService.printReceipt58mm(testData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.print,
              color: Colors.deepPurple.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select Bluetooth Printer',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Searching for paired printers...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_savedPrinterName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active: $_savedPrinterName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              await ReceiptService.clearSavedPrinter();
                              setState(() {
                                _savedPrinterName = null;
                                _selectedPrinter = null;
                              });
                            },
                            child: const Icon(Icons.close, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  if (_printers.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bluetooth_searching, color: Colors.orange.shade800, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'No Paired Printers Found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1. Pair your 58mm printer in your device Bluetooth settings (PIN: 0000 or 1234).\n'
                            '2. On Android, you can also use "RawBT" or "ESC POS Print Service" for direct driver access.\n'
                            '3. Or tap "System Print" below to print via standard print services.',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade900, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text(
                      'Tap your 58mm printer to connect:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _printers.length,
                        itemBuilder: (context, index) {
                          final p = _printers[index];
                          final isSelected = p.name == _savedPrinterName;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? Colors.deepPurple.shade300 : Colors.grey.shade200,
                              ),
                            ),
                            leading: Icon(
                              Icons.bluetooth,
                              color: isSelected ? Colors.deepPurple.shade700 : Colors.grey.shade600,
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.green, size: 20)
                                : null,
                            onTap: () => _saveAndSelectPrinter(p),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _testPrint(_selectedPrinter),
          icon: const Icon(Icons.receipt, size: 16),
          label: const Text('Test Print'),
        ),
        TextButton(
          onPressed: () => _loadPrinters(),
          child: const Text('Refresh'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedPrinter),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

extension on String {
  String center(int width) {
    if (length >= width) return this;
    final leftPadding = (width - length) ~/ 2;
    final rightPadding = width - length - leftPadding;
    return '${' ' * leftPadding}$this${' ' * rightPadding}';
  }
}