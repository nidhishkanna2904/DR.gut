import 'package:flutter/foundation.dart';

/// Application configuration constants.
class AppConfig {
  /// Base URL for the Dr Gut FastAPI backend.
  /// 10.0.2.2:8000 points to localhost on an Android emulator.
  /// If running on web or desktop, localhost:8000 is used directly.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Max upload file size in bytes (10 MB).
  static const int maxReportSizeBytes = 10 * 1024 * 1024;
}
