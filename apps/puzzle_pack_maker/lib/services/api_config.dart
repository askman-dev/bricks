import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String productionApiBaseUrl = 'https://craft.bricks.cool';

  static const String _apiBaseUrl = String.fromEnvironment(
    'BRICKS_API_BASE_URL',
    defaultValue: '',
  );

  static String resolveBaseUrl() {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kIsWeb) return Uri.base.origin;
    if (kReleaseMode || defaultTargetPlatform == TargetPlatform.iOS) {
      return productionApiBaseUrl;
    }
    return 'http://localhost:3000';
  }
}
