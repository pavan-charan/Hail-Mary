import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Smart Civic Sanitation';
  static const String appSubtitle = 'Sanitation & Drinking Water Platform';
  
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://lsoxfxycwqykjwjingen.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_6Ga73T7SE_a_EgH7pk9JIQ_Yfo5aa_Q';
  
  // Default coordinates (Kochi Municipal Corporation / Ernakulam Center)
  static const double defaultLat = 9.9723;
  static const double defaultLon = 76.2831;
  
  // Geo-fence distance in meters
  static const double maxCheckInDistanceMeters = 30.0;
}
