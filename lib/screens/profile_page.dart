// lib/screens/profile_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../authentication/login.dart';
import '../services/auth_service.dart';
import '../services/stats_service.dart';
import '../services/receipt_service.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isLoadingStats = true;

  // User profile data
  String _username = 'User';
  String _email = 'user@example.com';
  String _storeName = 'My Store';
  String _storeAddress = '123 Main Street, City';
  String _phoneNumber = '+63 912 345 6789';
  String _role = 'Admin';

  // Live accurate statistics from database
  int _productsCount = 0;
  int _transactionsCount = 0;
  double _totalSales = 0.0;
  int _customersCount = 0;

  // Controllers for editing
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileStats();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _username = prefs.getString('username') ?? 'User';
        _email = prefs.getString('email') ?? 'user@example.com';
        _storeName = prefs.getString('store_name') ?? 'My Store';
        _storeAddress = prefs.getString('store_address') ?? '123 Main Street, City';
        _phoneNumber = prefs.getString('phone') ?? '+63 912 345 6789';
        _role = prefs.getString('role') ?? 'Admin';
      });
    } catch (_) {
      // Use default values if shared preferences fails
    }
  }

  Future<void> _loadProfileStats() async {
    try {
      setState(() {
        _isLoadingStats = true;
      });

      final stats = await StatsService.getStats();

      if (!mounted) return;

      setState(() {
        _productsCount = stats.totalProducts;
        _transactionsCount = stats.totalOrders;
        _totalSales = stats.totalSales;
        _customersCount = stats.uniqueCustomers;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadUserData(),
      _loadProfileStats(),
    ]);
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  Future<void> _saveUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newUsername = _usernameController.text.trim();
      final newEmail = _emailController.text.trim();
      final newStoreName = _storeNameController.text.trim();
      final newStoreAddress = _storeAddressController.text.trim();
      final newPhone = _phoneController.text.trim();

      // Update backend database and local SharedPreferences
      final result = await AuthService.updateProfile(
        username: newUsername,
        email: newEmail,
        storeName: newStoreName,
        storeAddress: newStoreAddress,
        phone: newPhone,
        originalUsername: _username,
        originalEmail: _email,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _username = newUsername;
          _email = newEmail;
          _storeName = newStoreName;
          _storeAddress = newStoreAddress;
          _phoneNumber = newPhone;
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startEditing() {
    _usernameController.text = _username;
    _emailController.text = _email;
    _storeNameController.text = _storeName;
    _storeAddressController.text = _storeAddress;
    _phoneController.text = _phoneNumber;
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store,
              color: Colors.deepPurple.shade700,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.deepPurple.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!_isEditing)
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Colors.deepPurple.shade700,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.deepPurple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing) ...[
            IconButton(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Statistics',
            ),
            IconButton(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
            ),
          ],
          if (_isEditing) ...[
            IconButton(
              onPressed: _cancelEditing,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
            IconButton(
              onPressed: _saveUserData,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Save',
            ),
          ],
        ],
      ),
      body: _isLoading && !_isEditing
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              color: Colors.deepPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Image
                    Center(
                      child: _buildProfileImage(),
                    ),
                    const SizedBox(height: 16),
                    // Username
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Edit Mode
                    if (_isEditing) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildEditField('Username', _usernameController, Icons.person),
                            _buildEditField('Email', _emailController, Icons.email),
                            _buildEditField('Store Name', _storeNameController, Icons.store),
                            _buildEditField('Store Address', _storeAddressController, Icons.location_on),
                            _buildEditField('Phone Number', _phoneController, Icons.phone),
                          ],
                        ),
                      ),
                    ],

                    // Info Cards
                    if (!_isEditing) ...[
                      _buildInfoItem(Icons.email, 'Email', _email),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.store, 'Store Name', _storeName),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.location_on, 'Store Address', _storeAddress),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.phone, 'Phone Number', _phoneNumber),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.verified, 'Role', _role),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          await ReceiptService.selectPrinter(context);
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.deepPurple.shade200,
                            ),
                          ),
                          child: Row(
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
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thermal / Bluetooth Printer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FutureBuilder<String?>(
                                      future: ReceiptService.getSavedPrinterName(),
                                      builder: (context, snapshot) {
                                        final name = snapshot.data;
                                        return Text(
                                          name ?? 'Tap to select 58mm printer',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: name != null ? Colors.black87 : Colors.deepPurple.shade700,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),


                    // Live Stats Section from Database
                    if (!_isEditing) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Store Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isLoadingStats)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Products',
                              _isLoadingStats ? '...' : '$_productsCount',
                              Icons.inventory_2,
                              Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Transactions',
                              _isLoadingStats ? '...' : '$_transactionsCount',
                              Icons.receipt_long,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Sales',
                              _isLoadingStats ? '...' : '₱${_formatCurrency(_totalSales)}',
                              Icons.attach_money,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Customers',
                              _isLoadingStats ? '...' : '$_customersCount',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Logout Button
                    if (!_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _showLogoutDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.red.shade200,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Version Info
                    Center(
                      child: Text(
                        'Inventory Management v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}