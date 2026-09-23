class AppConfig {
  static const String appName = 'Smart Civic Sanitation';
  static const String appSubtitle = 'Sanitation & Drinking Water Platform';
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
  
  // Default coordinates (Kochi Municipal Corporation / Ernakulam Center)
  static const double defaultLat = 9.9723;
  static const double defaultLon = 76.2831;
  
  // Geo-fence distance in meters
  static const double maxCheckInDistanceMeters = 30.0;
}
