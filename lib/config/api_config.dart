/// Runtime configuration for the mobile application.
class ApiConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vdqdithxujxvzyybjtpn.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static String get placesEndpoint {
    final clean = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    return clean.endsWith('/rest/v1')
        ? '$clean/places'
        : '$clean/rest/v1/places';
  }

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get isGoogleConfigured => googleMapsApiKey.isNotEmpty;

  static Map<String, String> get headers {
    final authorization = ['Bearer', supabaseAnonKey].join(' ');
    return {
      'apikey': supabaseAnonKey,
      'Authorization': authorization,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }
}
