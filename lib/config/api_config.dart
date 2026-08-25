// lib/config/api_config.dart

class ApiConfig {
  /// Set your computer/server IP address or domain here.
  static const String serverIp = String.fromEnvironment(
    'SERVER_IP',
    defaultValue: '192.168.1.213',
  );

  static const String baseUrl = 'http://$serverIp/barcode';

 static const String productsUrl = '$baseUrl/products';

 static const String authUrl = '$baseUrl/auth';

  static const String statsUrl = '$productsUrl/get_stats.php';
}

