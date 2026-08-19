// lib/widgets/printer_dialog.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/receipt_service.dart';
import 'receipt_view.dart';

/// Shows the custom in-app Receipt and Printer UI Modal
Future<void> showReceiptPrintModal({
  required BuildContext context,
  required Map<String, dynamic> orderData,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReceiptPrintModal(orderData: orderData),
  );
}

/// Custom in-app Receipt & Printer Modal with live paper receipt preview
class ReceiptPrintModal extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const ReceiptPrintModal({
    super.key,
    required this.orderData,
  });

  @override
  State<ReceiptPrintModal> createState() => _ReceiptPrintModalState();
}

class _ReceiptPrintModalState extends State<ReceiptPrintModal> {
  DiscoveredPrinter? _selectedPrinter;
  String? _savedPrinterName;
  String? _savedPrinterType;
  bool _isPrinting = false;
  bool _isLoadingPrinter = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPrinter();
  }

  Future<void> _loadCurrentPrinter() async {
    setState(() {
      _isLoadingPrinter = true;
    });

    final savedName = await ReceiptService.getSavedPrinterName();
    final savedType = await ReceiptService.getSavedPrinterType();
    final printer = await ReceiptService.getSavedPrinter();

    if (mounted) {
      setState(() {
        _savedPrinterName = savedName;
        _savedPrinterType = savedType ?? printer?.connectionType;
        _selectedPrinter = printer;
        _isLoadingPrinter = false;
      });
    }
  }

  Future<void> _openPrinterSelection() async {
    final chosen = await showDialog<DiscoveredPrinter>(
      context: context,
      builder: (context) => const PrinterSelectionDialog(),
    );

    if (chosen != null && mounted) {
      setState(() {
        _selectedPrinter = chosen;
        _savedPrinterName = chosen.name;
        _savedPrinterType = chosen.connectionType;
      });
    } else {
      _loadCurrentPrinter();
    }
  }

  Future<void> _handlePrint() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      final success = await ReceiptService.printOrder(
        widget.orderData,
        targetPrinter: _selectedPrinter,
        context: context,
      );

      if (!mounted) return;

      setState(() {
        _isPrinting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _selectedPrinter != null
                      ? '✓ Sent to ${_selectedPrinter!.name} (${_savedPrinterType ?? "Thermal"})'
                      : '✓ Receipt printed successfully!',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copyReceiptText() async {
    final text = await ReceiptService.generateTextReceipt(widget.orderData);
    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Receipt copied to clipboard'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeName = _selectedPrinter?.name ?? _savedPrinterName;
    final isUsb = (_savedPrinterType ?? '').contains('USB') || (_savedPrinterType ?? '').contains('Wired');

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      maxChildSize: 0.95,
      minChildSize: 0.50,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header Drag Handle & Title
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.print,
                            color: Colors.deepPurple.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt & Printer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Supports Bluetooth & Wired USB (58mm)',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _copyReceiptText,
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy Receipt Text',
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Selected Printer Status Bar (Wired USB / Bluetooth)
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: activeName != null
                            ? (isUsb ? Colors.blue.shade50 : Colors.deepPurple.shade50)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUsb ? Icons.usb_rounded : Icons.bluetooth,
                        color: activeName != null
                            ? (isUsb ? Colors.blue.shade700 : Colors.deepPurple.shade700)
                            : Colors.orange.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  activeName ?? 'No Printer Selected',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_savedPrinterType != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isUsb ? Colors.blue.shade100 : Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _savedPrinterType!,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isUsb ? Colors.blue.shade900 : Colors.purple.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _isLoadingPrinter
                                ? 'Checking saved printer...'
                                : activeName != null
                                    ? 'Ready for 58mm printing'
                                    : 'Tap Select to connect Bluetooth / USB Cable',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openPrinterSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(activeName != null ? 'Change' : 'Select'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Receipt Paper Viewport
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(
                      child: ReceiptView(
                        orderData: widget.orderData,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Action Controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Select / Change Printer Button
                      OutlinedButton.icon(
                        onPressed: _openPrinterSelection,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          side: BorderSide(color: Colors.deepPurple.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        icon: const Icon(Icons.bluetooth_searching, size: 18),
                        label: const Text('Printers'),
                      ),
                      const SizedBox(width: 10),

                      // Print Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _handlePrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print, size: 20),
                          label: Text(
                            _isPrinting ? 'PRINTING...' : 'PRINT RECEIPT (58mm)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
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
      },
    );
  }
}

/// Custom in-app dialog widget for managing and selecting Bluetooth & Wired USB Printers
class PrinterSelectionDialog extends StatefulWidget {
  const PrinterSelectionDialog({super.key});

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<DiscoveredPrinter> _allPrinters = [];
  bool _isLoading = true;
  String? _savedPrinterName;
  String? _savedPrinterType;
  DiscoveredPrinter? _selectedPrinter;
  String _selectedFilter = 'All'; // 'All', 'Bluetooth', 'Wired USB'

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
      final savedType = await ReceiptService.getSavedPrinterType();
      final list = await ReceiptService.getAllPrinters();

      DiscoveredPrinter? matched;
      if (savedName != null && list.isNotEmpty) {
        try {
          matched = list.firstWhere(
            (p) => p.name == savedName,
          );
        } catch (_) {
          matched = list.first;
        }
      }

      if (mounted) {
        setState(() {
          _allPrinters = list;
          _savedPrinterName = savedName;
          _savedPrinterType = savedType;
          _selectedPrinter = matched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allPrinters = [];
          _isLoading = false;
        });
      }
    }
  }

  List<DiscoveredPrinter> _getFilteredPrinters() {
    if (_selectedFilter == 'All') return _allPrinters;

    return _allPrinters.where((p) {
      if (_selectedFilter == 'Wired USB') {
        return p.connectionType == 'USB Wired';
      } else if (_selectedFilter == 'Bluetooth') {
        return p.connectionType == 'Bluetooth';
      }
      return true;
    }).toList();
  }

  Future<void> _saveAndSelectPrinter(DiscoveredPrinter printer) async {
    await ReceiptService.savePrinter(printer);

    setState(() {
      _savedPrinterName = printer.name;
      _savedPrinterType = printer.connectionType;
      _selectedPrinter = printer;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                printer.connectionType == 'USB Wired' ? Icons.usb : Icons.bluetooth,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('✓ Default printer: ${printer.name} (${printer.connectionType})'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, printer);
    }
  }

  Future<void> _testPrint(DiscoveredPrinter? printer) async {
    final testData = {
      'customer_name': 'Officom 58mm Test',
      'items': [
        {
          'product_name': 'Officom Thermal Test Slip',
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

    final success = await ReceiptService.printOrder(
      testData,
      targetPrinter: printer,
      context: context,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Test slip sent to printer!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPrinters = _getFilteredPrinters();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Thermal Printer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bluetooth Devices & Wired USB',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Saved Printer Banner
            if (_savedPrinterName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                        'Active: $_savedPrinterName (${_savedPrinterType ?? "Thermal"})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        await ReceiptService.clearSavedPrinter();
                        setState(() {
                          _savedPrinterName = null;
                          _savedPrinterType = null;
                          _selectedPrinter = null;
                        });
                      },
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),

            // Connection Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', Icons.devices_other),
                  const SizedBox(width: 6),
                  _buildFilterChip('Bluetooth', Icons.bluetooth),
                  const SizedBox(width: 6),
                  _buildFilterChip('Wired USB', Icons.usb),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Printers List or Loading / Help Guide
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Scanning paired Bluetooth & USB devices...', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              )
            else if (filteredPrinters.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth_searching, color: Colors.deepPurple.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'No Paired Bluetooth Devices Found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Turn ON your Officom / POS-58 printer.\n'
                      '2. Open phone Settings -> Bluetooth -> Pair new device (PIN: 0000 or 1234).\n'
                      '3. Once paired in Bluetooth settings, tap "Refresh" below.',
                      style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade900, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredPrinters.length,
                  itemBuilder: (context, index) {
                    final p = filteredPrinters[index];
                    final isSelected = p.name == _savedPrinterName;
                    final isUsb = p.connectionType == 'USB Wired';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? Colors.deepPurple.shade400 : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isUsb ? Colors.blue.shade50 : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isUsb ? Icons.usb_rounded : Icons.bluetooth,
                            color: isUsb ? Colors.blue.shade700 : Colors.purple.shade700,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${p.connectionType} ${p.address.isNotEmpty ? "• ${p.address}" : ""}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                        onTap: () => _saveAndSelectPrinter(p),
                      ),
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
          label: const Text('Test Slip'),
        ),
        TextButton.icon(
          onPressed: _loadPrinters,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
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

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.deepPurple.shade700,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
    );
  }
}
