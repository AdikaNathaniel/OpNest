import 'package:flutter/foundation.dart';

/// Where the OpNest backend lives. Override at build time with
/// `--dart-define=API_BASE_URL=https://your-server.example.com`.
String get apiBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;
  // The Android emulator reaches the host machine through 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}
