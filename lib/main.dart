import 'package:flutter/material.dart';
import 'screens/register_product_page.dart';
import 'screens/scan_product_page.dart'; // Add this import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: 'Inventory Management',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Add Scan Icon to AppBar
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanProductPage(),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Product',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2,
              size: 80,
              color: Colors.deepPurple,
            ),
            SizedBox(height: 16),
            Text(
              'Home Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to register a new product',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Or tap the scan icon to search for a product',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Scan Product FAB
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanProductPage(),
                ),
              );
            },
            backgroundColor: Colors.blue,
            tooltip: 'Scan Product',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 16),
          // Register Product FAB
          FloatingActionButton(
            heroTag: 'register',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterProductPage(),
                ),
              );
            },
            tooltip: 'Register Product',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}