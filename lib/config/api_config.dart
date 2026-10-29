/// ============================================================
/// KONFIGURASI WEB SERVICE — MAMPIR APP
/// ============================================================
/// File ini menyimpan URL dan API Key untuk koneksi ke Supabase REST API.
///
/// PETUNJUK UNTUK MAHASISWA:
/// 1. Buat akun gratis di https://supabase.com
/// 2. Buat project baru, lalu buat tabel 'places' sesuai struktur JSON di PRD.
/// 3. Salin URL dan anon key dari Settings > API di dashboard Supabase.
/// 4. Paste di bawah ini menggantikan string kosong.
///
/// JANGAN KHAWATIR: Jika URL/Key masih kosong atau salah,
/// aplikasi akan otomatis menggunakan data bawaan (fallback)
/// sehingga TIDAK AKAN CRASH.
/// ============================================================
class ApiConfig {
  /// URL dasar Supabase REST API (PostgREST).
  /// Contoh: 'https://abcdefghij.supabase.co/rest/v1'
  /// Kosongkan jika belum punya — aplikasi tetap jalan dengan data bawaan.
  static const String supabaseUrl = 'https://vdqdithxujxvzyybjtpn.supabase.co';

  /// Supabase Anon (Public) Key.
  /// Contoh: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
  /// Kosongkan jika belum punya — aplikasi tetap jalan dengan data bawaan.
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkcWRpdGh4dWp4dnp5eWJqdHBuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzA2NTIsImV4cCI6MjEwODgwNjY1Mn0.7zE0gLxh0a2DNzdVcRfTj3EZDaqXWZ09kL5gcXTETXY';

  /// Endpoint untuk mengambil data tempat (GET request)
  static String get placesEndpoint {
    final clean = supabaseUrl.endsWith('/') ? supabaseUrl.substring(0, supabaseUrl.length - 1) : supabaseUrl;
    return clean.endsWith('/rest/v1') ? '$clean/places' : '$clean/rest/v1/places';
  }

  /// Mengecek apakah konfigurasi Supabase sudah diisi oleh pengguna.
  /// Jika false, ApiService akan menggunakan data fallback bawaan.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Header standar untuk request ke Supabase REST API.
  /// Berisi API Key dan format response JSON.
  static Map<String, String> get headers => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
}
