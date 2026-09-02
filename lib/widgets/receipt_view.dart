// lib/widgets/receipt_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptView extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String? storeName;
  final String? storeAddress;
  final String? phone;
  final String? cashierName;

  const ReceiptView({
    super.key,
    required this.orderData,
    this.storeName,
    this.storeAddress,
    this.phone,
    this.cashierName,
  });

  @override
  State<ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  String _storeName = 'INVENTORY SYSTEM';
  String _storeAddress = '123 Main Street, City';
  String _phone = '+63 912 345 6789';
  String _cashier = 'Cashier';

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _storeName = widget.storeName ??
          widget.orderData['store_name']?.toString() ??
          prefs.getString('store_name') ??
          'INVENTORY SYSTEM';
      _storeAddress = widget.storeAddress ??
          widget.orderData['store_address']?.toString() ??
          prefs.getString('store_address') ??
          '123 Main Street, City';
      _phone = widget.phone ??
          widget.orderData['phone']?.toString() ??
          prefs.getString('phone') ??
          '+63 912 345 6789';
      _cashier = widget.cashierName ??
          widget.orderData['cashier_name']?.toString() ??
          widget.orderData['cashier']?.toString() ??
          prefs.getString('username') ??
          'Cashier';
    });
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final parsed = DateTime.tryParse(dateVal.toString());
    if (parsed == null) return dateVal.toString();
    return DateFormat('MMM dd, yyyy  hh:mm a').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.orderData['items'] as List<dynamic>?) ?? [];
    final totalAmount = _toDouble(widget.orderData['total_amount']);
    final cashReceived = _toDouble(widget.orderData['cash_received'] ?? widget.orderData['total_amount']);
    final change = _toDouble(widget.orderData['change'] ?? widget.orderData['change_amount']);
    final customerName = (widget.orderData['customer_name']?.toString() ?? '').trim().isEmpty
        ? 'Walk-in Customer'
        : widget.orderData['customer_name'].toString();
    final rawDate = widget.orderData['order_date'] ?? widget.orderData['created_at'];
    final dateStr = _formatDate(rawDate);
    final orderId = widget.orderData['order_id'] ??
        widget.orderData['id'] ??
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFA),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Serrated / Jagged Paper Cut Top Edge
            CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _ZigZagTopPainter(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store Header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _storeName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _storeAddress,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Tel: $_phone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54, width: 0.8),
                          ),
                          child: const Text(
                            '*** OFFICIAL RECEIPT ***',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildDottedLine(),
                  const SizedBox(height: 8),

                  // Order Metadata
                  _buildMetaLine('Receipt #:', 'INV-$orderId'),
                  _buildMetaLine('Date:', dateStr),
                  _buildMetaLine('Cashier:', _cashier),
                  _buildMetaLine('Customer:', customerName),

                  const SizedBox(height: 8),
                  _buildDottedLine(),
                  const SizedBox(height: 8),

                  // Table Header
                  const Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Text(
                          'ITEM / QTY / PRICE',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          'TOTAL',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  _buildDottedLine(),
                  const SizedBox(height: 6),

                  // Items List
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No items',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Courier', fontSize: 11),
                      ),
                    )
                  else
                    ...items.map((item) {
                      final name = item['product_name']?.toString() ?? 'Product';
                      final qty = _toInt(item['quantity'] ?? 1);
                      final price = _toDouble(item['price']);
                      final total = _toDouble(item['total'] ?? (price * qty));

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Text(
                                    '  ${qty}x  @  ₱${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    '₱${total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                  _buildDottedLine(),
                  const SizedBox(height: 8),

                  // Totals
                  _buildSummaryLine(
                    'TOTAL AMOUNT:',
                    '₱${totalAmount.toStringAsFixed(2)}',
                    isBold: true,
                    fontSize: 14,
                  ),
                  const SizedBox(height: 4),
                  _buildSummaryLine(
                    'Cash Received:',
                    '₱${cashReceived.toStringAsFixed(2)}',
                    fontSize: 11.5,
                  ),
                  const SizedBox(height: 2),
                  _buildSummaryLine(
                    'Change:',
                    '₱${change.toStringAsFixed(2)}',
                    isBold: true,
                    fontSize: 12,
                    color: Colors.green.shade800,
                  ),

                  const SizedBox(height: 10),
                  _buildDottedLine(),
                  const SizedBox(height: 12),

                  // Barcode Graphic & Footer
                  Center(
                    child: Column(
                      children: [
                        _buildBarcodeGraphic(orderId.toString()),
                        const SizedBox(height: 4),
                        Text(
                          '* INV-$orderId *',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 9.5,
                            letterSpacing: 2,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Thank you for your purchase!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Please keep this receipt for warranty.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 9.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),

            // Serrated / Jagged Paper Cut Bottom Edge
            CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _ZigZagBottomPainter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedLine() {
    return Row(
      children: List.generate(
        36,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.grey.shade600 : Colors.transparent,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10.5,
              color: Colors.grey.shade700,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeGraphic(String code) {
    // Generate barcode visual pattern
    return SizedBox(
      height: 28,
      width: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          42,
          (index) {
            final isThick = (index * 7 + code.hashCode) % 3 == 0;
            final isSpace = (index * 13 + code.hashCode) % 4 == 0;
            return Container(
              width: isSpace ? 1.5 : (isThick ? 3.0 : 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: isSpace ? Colors.transparent : Colors.black87,
            );
          },
        ),
      ),
    );
  }
}

class _ZigZagTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    final toothHeight = size.height;
    final count = (size.width / toothWidth).ceil();

    path.moveTo(0, toothHeight);
    for (int i = 0; i < count; i++) {
      final x = i * toothWidth;
      path.lineTo(x + toothWidth / 2, 0);
      path.lineTo(x + toothWidth, toothHeight);
    }
    path.lineTo(size.width, toothHeight);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZigZagBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    final toothHeight = size.height;
    final count = (size.width / toothWidth).ceil();

    path.moveTo(0, 0);
    for (int i = 0; i < count; i++) {
      final x = i * toothWidth;
      path.lineTo(x + toothWidth / 2, toothHeight);
      path.lineTo(x + toothWidth, 0);
    }
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
