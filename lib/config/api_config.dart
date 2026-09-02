// lib/config/api_config.dart

class ApiConfig {
  /// Set your computer/server IP address here (e.g., '192.168.1.100' or '10.0.2.2')
  static const String serverIp = String.fromEnvironment(
    'SERVER_IP',
    defaultValue: ' 192.168.68.215',
  );

  static const String baseUrl = 'http://$serverIp/barcode';

  static const String productsUrl = '$baseUrl/products';

  static const String authUrl = '$baseUrl/auth';

  static const String statsUrl = '$productsUrl/get_stats.php';
}
