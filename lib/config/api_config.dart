// lib/config/api_config.dart

class ApiConfig {
  /// Set your computer/server IP address or domain here.
  /// You can edit it here directly in ONE place, or pass via command line:
  /// flutter run --dart-define=SERVER_IP=192.168.1.150
  static const String serverIp = String.fromEnvironment(
    'SERVER_IP',
    defaultValue: '192.168.1.150',
  );

  /// Base API URL (e.g. http://192.168.1.150/barcode)
  static const String baseUrl = 'http://$serverIp/barcode';

  /// Products endpoints (e.g. http://192.168.1.150/barcode/products)
  static const String productsUrl = '$baseUrl/products';

  /// Auth endpoints (e.g. http://192.168.1.150/barcode/auth)
  static const String authUrl = '$baseUrl/auth';

  /// Stats endpoint (e.g. http://192.168.1.150/barcode/products/get_stats.php)
  static const String statsUrl = '$productsUrl/get_stats.php';
}

