/// Runtime configuration for the mobile application.
class ApiConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oztqhofaadjldjrowrgy.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96dHFob2ZhYWRqbGRqcm93cmd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ5NzM4MzEsImV4cCI6MjExMDU0OTgzMX0.Do3ET862Lik6anMGmazYswh_8hBCX6Iz_80jqWuI4-U',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_pjWlPUm49bsg3G1L7J3SBg_D8TkYag1',
  );

  /// Service role key & backend secrets must NEVER be hardcoded into the client app.
  /// Privileged operations must be executed in secure backend environments
  /// (e.g. Supabase Edge Functions / Admin servers) where keys are kept in environment variables.
  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: '',
  );

  static const String supabaseApiSecretKey = String.fromEnvironment(
    'SUPABASE_SECRET_KEY',
    defaultValue: '',
  );

  /// Callback redirect URL untuk Google OAuth via Supabase:
  /// - Pada Android Native: mampir://auth-callback (dapat dioverride via AUTH_CALLBACK_URL)
  /// - Pada Web: menggunakan runtime browser origin (Uri.base.origin)
  static const String androidAuthCallback = String.fromEnvironment(
    'AUTH_CALLBACK_URL',
    defaultValue: 'mampir://auth-callback',
  );

  // Google Maps API Keys.
  //
  // Jangan hardcode key di source code. Suntikkan saat build/run:
  //   flutter run \
  //     --dart-define=GOOGLE_PLACES_API_KEY=... \
  //     --dart-define=GOOGLE_ROUTES_API_KEY=...
  //
  // GOOGLE_MAPS_API_KEY untuk Android Maps SDK diatur lewat
  // android/gradle.properties (manifestPlaceholder), bukan lewat Dart.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDMJEEWy4XuVJSIzvzEVKS6zfwtVjGSYGk',
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
