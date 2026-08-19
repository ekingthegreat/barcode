// lib/screens/transactions_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/order_service.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String _filterType = 'All'; // All, Today, Week, Month
  String _sortBy = 'date'; // date, amount

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await OrderService.getAllOrders();
      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load transactions: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    var filtered = List<Map<String, dynamic>>.from(_transactions);

    // Filter by date range
    final now = DateTime.now();
    switch (_filterType) {
      case 'Today':
        filtered = filtered.where((t) {
          final date = DateTime.tryParse(t['order_date']?.toString() ?? '');
          if (date == null) return false;
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).toList();
        break;
      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((t) {
          final date = DateTime.tryParse(t['order_date']?.toString() ?? '');
          if (date == null) return false;
          return date.isAfter(weekAgo);
        }).toList();
        break;
      case 'Month':
        final monthAgo = now.subtract(const Duration(days: 30));
        filtered = filtered.where((t) {
          final date = DateTime.tryParse(t['order_date']?.toString() ?? '');
          if (date == null) return false;
          return date.isAfter(monthAgo);
        }).toList();
        break;
      case 'All':
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) =>
        (t['customer_name']?.toString() ?? '').toLowerCase().contains(query) ||
        (t['order_id']?.toString() ?? '').toLowerCase().contains(query)
      ).toList();
    }

    // Sort transactions
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) =>
            (b['order_date']?.toString() ?? '').compareTo(a['order_date']?.toString() ?? ''));
        break;
      case 'amount':
        filtered.sort((a, b) {
          final amountA = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
          final amountB = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
          return amountB.compareTo(amountA);
        });
        break;
    }

    return filtered;
  }

  double _getTotalSales() {
    final filtered = _getFilteredTransactions();
    return filtered.fold<double>(
      0.0,
      (sum, t) => sum + ((t['total_amount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  int _getTotalItems() {
    final filtered = _getFilteredTransactions();
    return filtered.fold<int>(0, (sum, t) {
      final items = t['items'] as List? ?? [];
      return sum +
          items.fold<int>(
            0,
            (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0),
          );
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final items = transaction['items'] as List? ?? [];
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.green.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${transaction['order_id']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            transaction['customer_name'] ?? 'Walk-in Customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      'Date',
                      dateFormat.format(DateTime.tryParse(transaction['order_date']?.toString() ?? '') ?? DateTime.now()),
                      Icons.calendar_today,
                      Colors.blue,
                    ),
                    _buildStatChip(
                      'Items',
                      items.length.toString(),
                      Icons.shopping_bag,
                      Colors.orange,
                    ),
                    _buildStatChip(
                      'Total',
                      '₱${transaction['total_amount'].toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                // Items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${items.length} item(s)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Items list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['product_name'] ?? 'Unknown Product',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '₱${(item['price'] ?? 0).toStringAsFixed(2)} × ${item['quantity']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${(item['total'] ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Payment details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildPaymentRow('Subtotal', transaction['total_amount']),
                      _buildPaymentRow('Cash Received', transaction['cash_received']),
                      const Divider(height: 12),
                      _buildPaymentRow(
                        'Change',
                        transaction['change'],
                        color: Colors.green,
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, double? amount, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            '₱${(amount ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();
    final totalSales = _getTotalSales();
    final totalItems = _getTotalItems();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by customer or order ID...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text(
                'Transactions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
        backgroundColor: Colors.deepPurple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (!_isSearching) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(Icons.search),
              tooltip: 'Search',
            ),
            IconButton(
              onPressed: _loadTransactions,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ] else ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.close),
              tooltip: 'Close Search',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Stats Summary
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    '₱${totalSales.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Items',
                    totalItems.toString(),
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Orders',
                    filteredTransactions.length.toString(),
                    Icons.receipt_long,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Time filters
                  ...['All', 'Today', 'Week', 'Month'].map((filter) {
                    final isSelected = filter == _filterType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _filterType = filter;
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.deepPurple.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  // Sort Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: Icon(Icons.sort, color: Colors.grey.shade700),
                        items: const [
                          DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                          DropdownMenuItem(value: 'amount', child: Text('Sort by Amount')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Transaction List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepPurple,
                    ),
                  )
                : filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No transactions found'
                                  : 'No transactions yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try adjusting your search'
                                  : 'Transactions will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _isSearching = false;
                                  });
                                },
                                child: const Text('Clear Search'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final date = DateTime.tryParse(transaction['order_date']?.toString() ?? '') ?? DateTime.now();
    final items = transaction['items'] as List? ?? [];
    final itemCount = items.length;
    
    // Determine if it's a recent transaction (within last hour)
    final isRecent = DateTime.now().difference(date).inHours < 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isRecent ? Colors.green.shade700 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Transaction info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${transaction['order_id']}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRecent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'New',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              transaction['customer_name'] ?? 'Walk-in Customer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${(transaction['total_amount'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount item${itemCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Footer with date and payment info
              const Divider(height: 4),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${dateFormat.format(date)} at ${timeFormat.format(date)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 10,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Cash',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}