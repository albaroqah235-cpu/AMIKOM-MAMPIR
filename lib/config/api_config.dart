/// Runtime configuration for the mobile application.
class ApiConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vdqdithxujxvzyybjtpn.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkcWRpdGh4dWp4dnp5eWJqdHBuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzA2NTIsImV4cCI6MjEwODgwNjY1Mn0.7zE0gLxh0a2DNzdVcRfTj3EZDaqXWZ09kL5gcXTETXY',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_9-reGMqpk71zyWtbiBvOQA_kjQ9sbmS',
  );

  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkcWRpdGh4dWp4dnp5eWJqdHBuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MzIzMDY1MiwiZXhwIjoyMTA4ODA2NjUyfQ.9nGWj3OIhRnOdloWDnQ3XGanKLJwgbng20BqGMWk0hc',
  );

  static const String supabaseApiSecretKey = String.fromEnvironment(
    'SUPABASE_SECRET_KEY',
    defaultValue: 'sb_secret_yhkjmZ6AT_6vv2Np8q_BLw_qpuFOOt3',
  );

  // Google Maps API Keys
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDRpM6qUNluR7y-yP-k0UEhSrNQQ84A9nI',
  );

  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'AIzaSyDMJEEWy4XuVJSIzvzEVKS6zfwtVjGSYGk',
  );

  static const String googleRoutesApiKey = String.fromEnvironment(
    'GOOGLE_ROUTES_API_KEY',
    defaultValue: 'AIzaSyBucKKuasjZSWCt8DfCCTfw6omaV-qlqX8',
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
  static bool get isGoogleConfigured =>
      googlePlacesApiKey.isNotEmpty && googleRoutesApiKey.isNotEmpty;

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
