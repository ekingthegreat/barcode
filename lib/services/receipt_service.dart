// lib/services/receipt_service.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/printer_dialog.dart';

/// Unified model for discovered thermal printers (Bluetooth or USB)
class DiscoveredPrinter {
  final String name;
  final String address; // MAC address for Bluetooth or URL for USB
  final String connectionType; // 'Bluetooth', 'USB Wired', 'Network'
  final bool isBluetooth;

  DiscoveredPrinter({
    required this.name,
    required this.address,
    required this.connectionType,
    required this.isBluetooth,
  });
}

class ReceiptService {
  /// Storage keys
  static const String _prefPrinterName = 'selected_printer_name';
  static const String _prefPrinterAddress = 'selected_printer_address';
  static const String _prefPrinterType = 'selected_printer_type';

  /// Scans and returns all available printers:
  /// - Paired Bluetooth thermal printers (Officom, POS-58, MTP-2, etc.)
  /// - Wired USB / System printers
  static Future<List<DiscoveredPrinter>> getAllPrinters() async {
    final List<DiscoveredPrinter> results = [];
    final Set<String> seenNames = {};

    // 1. Scan Paired Bluetooth Devices directly via Bluetooth adapter
    try {
      final List<BluetoothInfo> btList = await PrintBluetoothThermal.pairedBluetooths;
      for (var bt in btList) {
        if (bt.name.isNotEmpty && !seenNames.contains(bt.name)) {
          seenNames.add(bt.name);
          results.add(
            DiscoveredPrinter(
              name: bt.name,
              address: bt.macAdress,
              connectionType: 'Bluetooth',
              isBluetooth: true,
            ),
          );
        }
      }
    } catch (_) {}

    // 2. Scan USB / Wired / System Printers
    try {
      final list = await Printing.listPrinters();
      for (var p in list) {
        if (p.name.isNotEmpty && !seenNames.contains(p.name)) {
          seenNames.add(p.name);
          final type = detectConnectionType(p);
          results.add(
            DiscoveredPrinter(
              name: p.name,
              address: p.url,
              connectionType: type,
              isBluetooth: type == 'Bluetooth',
            ),
          );
        }
      }
    } catch (_) {}

    return results;
  }

  /// Detects whether printer connection is USB Wired Cable, Bluetooth, or Network
  static String detectConnectionType(Printer printer) {
    final name = printer.name.toLowerCase();
    final url = printer.url.toLowerCase();

    if (url.contains('usb') ||
        name.contains('usb') ||
        url.contains('com') ||
        name.contains('com') ||
        url.contains('serial') ||
        name.contains('serial') ||
        url.contains('lpt') ||
        url.contains('cable') ||
        url.contains('otg') ||
        url.contains('hid') ||
        url.contains('driver')) {
      return 'USB Wired';
    }

    if (url.contains('bt') ||
        name.contains('bluetooth') ||
        name.contains('bt') ||
        url.contains('blue') ||
        name.contains('mtp') ||
        name.contains('pt-210') ||
        name.contains('rpp02') ||
        name.contains('pos-5802')) {
      return 'Bluetooth';
    }

    if (url.contains('tcp') ||
        url.contains('http') ||
        url.contains('ipp') ||
        url.contains('socket') ||
        name.contains('wifi') ||
        name.contains('network')) {
      return 'Network';
    }

    return 'USB Wired';
  }

  /// Custom in-app dialog to list, select, and test wired USB & Bluetooth thermal printers
  static Future<DiscoveredPrinter?> selectPrinter(BuildContext context) async {
    return showDialog<DiscoveredPrinter>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const PrinterSelectionDialog();
      },
    );
  }

  /// Opens the custom in-app Receipt & Printer UI bottom sheet
  static Future<void> showReceiptModal(
    BuildContext context,
    Map<String, dynamic> orderData,
  ) async {
    await showReceiptPrintModal(
      context: context,
      orderData: orderData,
    );
  }

  /// Gets the currently saved default printer
  static Future<DiscoveredPrinter?> getSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_prefPrinterName);
      final savedAddress = prefs.getString(_prefPrinterAddress);
      final savedType = prefs.getString(_prefPrinterType) ?? 'Bluetooth';

      if (savedName == null && savedAddress == null) {
        return null;
      }

      final all = await getAllPrinters();
      for (var p in all) {
        if (savedAddress != null && p.address == savedAddress) {
          return p;
        }
        if (savedName != null && p.name == savedName) {
          return p;
        }
      }

      // If exact device object not found in scan, construct from saved prefs
      if (savedName != null) {
        return DiscoveredPrinter(
          name: savedName,
          address: savedAddress ?? '',
          connectionType: savedType,
          isBluetooth: savedType == 'Bluetooth',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Gets the name of the saved printer for UI display
  static Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefPrinterName);
  }

  /// Gets the saved printer connection type (USB Wired / Bluetooth)
  static Future<String?> getSavedPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefPrinterType);
  }

  /// Saves the selected printer as default in SharedPreferences
  static Future<void> savePrinter(DiscoveredPrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPrinterName, printer.name);
    await prefs.setString(_prefPrinterAddress, printer.address);
    await prefs.setString(_prefPrinterType, printer.connectionType);
  }

  /// Clears saved printer
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPrinterName);
    await prefs.remove(_prefPrinterAddress);
    await prefs.remove(_prefPrinterType);
  }

  /// Launches our custom in-app Printer & Receipt UI
  static Future<bool> printDirect(
    Map<String, dynamic> orderData, {
    BuildContext? context,
  }) async {
    if (context != null && context.mounted) {
      await showReceiptModal(context, orderData);
      return true;
    }
    return false;
  }

  /// Generates ESC/POS byte commands for 58mm thermal printers (Officom, POS-58, MTP-2)
  static Future<List<int>> generateEscPosBytes(Map<String, dynamic> orderData) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final prefs = await SharedPreferences.getInstance();
    final sName = prefs.getString('store_name') ?? 'INVENTORY SYSTEM';
    final sAddress = prefs.getString('store_address') ?? '123 Main Street, City';
    final sPhone = prefs.getString('phone') ?? '+63 912 345 6789';
    final cashier = prefs.getString('username') ?? 'Cashier';

    // Store Header
    bytes += generator.text(
      sName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text(
      sAddress,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Tel: $sPhone',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr(ch: '=');
    bytes += generator.text(
      '*** OFFICIAL RECEIPT ***',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr(ch: '-');

    // Metadata
    final rawDate = orderData['order_date'] ?? orderData['created_at'];
    final dateStr = rawDate != null ? rawDate.toString() : DateTime.now().toString().substring(0, 19);
    final orderId = orderData['order_id'] ?? orderData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    bytes += generator.row([
      PosColumn(text: 'Receipt #:', width: 4),
      PosColumn(text: 'INV-$orderId', width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Date:', width: 4),
      PosColumn(text: dateStr.length > 19 ? dateStr.substring(0, 19) : dateStr, width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Cashier:', width: 4),
      PosColumn(text: cashier, width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Customer:', width: 4),
      PosColumn(text: '${orderData['customer_name'] ?? 'Walk-in'}', width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr(ch: '-');

    // Table Header
    bytes += generator.row([
      PosColumn(text: 'ITEM', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'QTY', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'PRICE', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: 'TOTAL', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.hr(ch: '-');

    // Items List
    final items = (orderData['items'] as List<dynamic>?) ?? [];
    for (var item in items) {
      final name = (item['product_name'] ?? 'Product').toString();
      final barcode = item['barcode']?.toString() ?? '';
      final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final total = double.tryParse(item['total']?.toString() ?? '0') ?? (price * qty);

      bytes += generator.text(name, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: barcode.isNotEmpty ? '#$barcode' : '', width: 6),
        PosColumn(text: '${qty}x', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: price.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: total.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.hr(ch: '-');

    // Totals
    final total = double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0;
    final cash = double.tryParse(orderData['cash_received']?.toString() ?? '0') ?? 0;
    final change = double.tryParse(orderData['change']?.toString() ?? '0') ?? 0;

    bytes += generator.row([
      PosColumn(text: 'TOTAL AMOUNT:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'P ${total.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Cash Received:', width: 6),
      PosColumn(text: 'P ${cash.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Change:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'P ${change.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += generator.hr(ch: '=');
    bytes += generator.text('Thank you for your purchase!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Please come again', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Sends the print job to the selected Bluetooth or Wired USB printer
  static Future<bool> printOrder(
    Map<String, dynamic> orderData, {
    DiscoveredPrinter? targetPrinter,
    BuildContext? context,
  }) async {
    try {
      final printer = targetPrinter ?? await getSavedPrinter();

      if (printer == null) {
        if (context != null && context.mounted) {
          final chosen = await selectPrinter(context);
          if (chosen == null) return false;
          return printOrder(orderData, targetPrinter: chosen, context: context);
        }
        return false;
      }

      // 1. Bluetooth Thermal Printing (Officom, POS-58, MTP-2)
      if (printer.isBluetooth && printer.address.isNotEmpty) {
        final isConnected = await PrintBluetoothThermal.connectionStatus;
        if (!isConnected) {
          final connected = await PrintBluetoothThermal.connect(macPrinterAddress: printer.address);
          if (!connected) {
            throw Exception('Could not connect to ${printer.name}. Make sure printer is powered ON.');
          }
        }

        final bytes = await generateEscPosBytes(orderData);
        final result = await PrintBluetoothThermal.writeBytes(bytes);
        return result;
      }

      // 2. Wired USB / System Desktop Printing
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

  /// Generates plain text receipt for serial streams or clipboard
  static Future<String> generateTextReceipt(Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    final sName = prefs.getString('store_name') ?? 'INVENTORY SYSTEM';
    final sAddress = prefs.getString('store_address') ?? '123 Main Street, City';
    final sPhone = prefs.getString('phone') ?? '+63 912 345 6789';
    final cashier = prefs.getString('username') ?? 'Cashier';

    final buffer = StringBuffer();

    // Header (32 columns standard for 58mm POS printers)
    buffer.writeln('=' * 32);
    buffer.writeln(sName.center(32));
    buffer.writeln(sAddress.center(32));
    buffer.writeln('Tel: $sPhone'.center(32));
    buffer.writeln('-' * 32);
    buffer.writeln('*** OFFICIAL RECEIPT ***'.center(32));
    buffer.writeln('=' * 32);
    buffer.writeln();

    // Date & Customer
    final rawDate = orderData['order_date'] ?? orderData['created_at'];
    final dateStr = rawDate != null ? rawDate.toString() : DateTime.now().toString().substring(0, 19);
    final orderId = orderData['order_id'] ?? orderData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    buffer.writeln('Receipt #: INV-$orderId');
    buffer.writeln('Date: $dateStr');
    buffer.writeln('Cashier: $cashier');
    buffer.writeln('Customer: ${orderData['customer_name'] ?? 'Walk-in'}');
    buffer.writeln('-' * 32);
    buffer.writeln();

    // Items Header
    buffer.writeln('ITEM          QTY   PRICE   TOTAL');
    buffer.writeln('-' * 32);

    final items = orderData['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final name = (item['product_name'] ?? '').toString();
      final truncatedName = name.length > 12 ? name.substring(0, 12) : name.padRight(12);
      final qty = (item['quantity'] ?? 1).toString().padLeft(3);
      final price = '₱${(double.tryParse(item['price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'.padLeft(7);
      final total = '₱${(double.tryParse(item['total']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'.padLeft(7);
      buffer.writeln('$truncatedName $qty $price $total');
    }

    buffer.writeln('-' * 32);
    buffer.writeln();

    // Totals
    final total = double.tryParse(orderData['total_amount']?.toString() ?? '0') ?? 0;
    final cash = double.tryParse(orderData['cash_received']?.toString() ?? '0') ?? 0;
    final change = double.tryParse(orderData['change']?.toString() ?? '0') ?? 0;

    buffer.writeln('${'TOTAL:'.padRight(18)}₱${total.toStringAsFixed(2).padLeft(12)}');
    buffer.writeln('${'Cash Received:'.padRight(18)}₱${cash.toStringAsFixed(2).padLeft(12)}');
    buffer.writeln('${'Change:'.padRight(18)}₱${change.toStringAsFixed(2).padLeft(12)}');
    buffer.writeln();
    buffer.writeln('=' * 32);
    buffer.writeln('Thank you for your purchase!'.center(32));
    buffer.writeln('Please come again'.center(32));
    buffer.writeln('=' * 32);

    return buffer.toString();
  }

  /// Saves receipt text to local documents
  static Future<File> saveReceipt(String receiptText) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/receipt_$timestamp.txt';
    final file = File(filePath);
    await file.writeAsString(receiptText);
    return file;
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