import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// ============================================================
/// AUTH SERVICE — AUTENTIKASI SUPABASE UNTUK MAMPIR APP
/// ============================================================
/// Semua komunikasi dengan Supabase Auth REST API:
/// - Sign Up, Sign In, Lupa Sandi (OTP), Reset Password
/// ============================================================
class AuthResult {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? userName;
  final String? userEmail;

  const AuthResult({
    required this.success,
    this.message,
    this.accessToken,
    this.userName,
    this.userEmail,
  });
}

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static String get _baseUrl {
    final raw = ApiConfig.supabaseUrl.trim();
    final clean = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    return '$clean/auth/v1';
  }

  static final Map<String, String> _headers = {
    'apikey': ApiConfig.supabaseAnonKey,
    'Content-Type': 'application/json',
  };

  // ==================== SIGN UP ====================
  /// Daftar akun baru dengan email & password.
  /// Mengembalikan [AuthResult] dengan status dan pesan.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/signup'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'password': password,
              'data': {'name': name, 'full_name': name},
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final user = (body['user'] as Map<String, dynamic>?) ??
            (body.containsKey('id') ? body : null);
        final meta = user?['user_metadata'] as Map<String, dynamic>?;
        final resolvedName =
            meta?['name'] as String? ?? meta?['full_name'] as String? ?? name;
        return AuthResult(
          success: true,
          message: 'Akun berhasil dibuat! Silakan masuk.',
          userName: resolvedName,
          userEmail: email,
        );
      } else {
        final msg = body['msg'] as String? ??
            body['message'] as String? ??
            'Gagal membuat akun. Pastikan email valid.';
        return AuthResult(success: false, message: msg);
      }
    } catch (e) {
      return const AuthResult(
          success: false,
          message: 'Koneksi gagal. Periksa sambungan internet kamu.');
    }
  }

  // ==================== SIGN IN ====================
  /// Login dengan email & password ke Supabase.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/token?grant_type=password'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final user = (body['user'] as Map<String, dynamic>?) ??
            (body.containsKey('id') ? body : null);
        final meta = user?['user_metadata'] as Map<String, dynamic>?;
        final resolvedName = meta?['name'] as String? ??
            meta?['full_name'] as String? ??
            email.split('@').first;
        return AuthResult(
          success: true,
          accessToken: body['access_token'] as String?,
          userName: resolvedName,
          userEmail: email,
        );
      } else {
        final msg = body['error_description'] as String? ??
            body['msg'] as String? ??
            'Email atau kata sandi salah.';
        return AuthResult(success: false, message: msg);
      }
    } catch (e) {
      return const AuthResult(
          success: false,
          message: 'Koneksi gagal. Periksa sambungan internet kamu.');
    }
  }

  // ==================== LUPA SANDI: KIRIM OTP ====================
  /// Mengirimkan kode OTP reset sandi ke email pengguna.
  Future<AuthResult> sendPasswordResetOtp(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/recover'),
            headers: _headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return const AuthResult(
          success: true,
          message: 'Kode OTP dikirim ke email kamu!',
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['msg'] as String? ?? 'Gagal mengirim OTP.';
        return AuthResult(success: false, message: msg);
      }
    } catch (e) {
      return const AuthResult(
          success: false,
          message: 'Koneksi gagal. Periksa sambungan internet kamu.');
    }
  }

  // ==================== VERIFIKASI OTP & RESET SANDI ====================
  /// Memverifikasi kode OTP dan langsung mengubah kata sandi baru.
  Future<AuthResult> verifyOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      // Langkah 1: Verifikasi OTP
      final verifyResponse = await _client
          .post(
            Uri.parse('$_baseUrl/verify'),
            headers: _headers,
            body: jsonEncode({
              'type': 'recovery',
              'email': email,
              'token': token,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final verifyBody =
          jsonDecode(verifyResponse.body) as Map<String, dynamic>;

      if (verifyResponse.statusCode != 200) {
        final msg = verifyBody['msg'] as String? ??
            'Kode OTP salah atau sudah kedaluwarsa. Coba kirim ulang.';
        return AuthResult(success: false, message: msg);
      }

      final accessToken = verifyBody['access_token'] as String?;
      if (accessToken == null) {
        return const AuthResult(
            success: false, message: 'Token tidak valid. Coba kirim ulang OTP.');
      }

      // Langkah 2: Update password menggunakan token dari verifikasi
      final updateResponse = await _client
          .put(
            Uri.parse('$_baseUrl/user'),
            headers: {
              'apikey': ApiConfig.supabaseAnonKey,
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'password': newPassword}),
          )
          .timeout(const Duration(seconds: 15));

      if (updateResponse.statusCode == 200) {
        return const AuthResult(
          success: true,
          message:
              'Kata sandi berhasil diubah! Silakan masuk dengan kata sandi baru.',
        );
      } else {
        final upBody =
            jsonDecode(updateResponse.body) as Map<String, dynamic>;
        final msg = upBody['msg'] as String? ?? 'Gagal mengubah kata sandi.';
        return AuthResult(success: false, message: msg);
      }
    } catch (e) {
      return const AuthResult(
          success: false,
          message: 'Koneksi gagal. Periksa sambungan internet kamu.');
    }
  }
}
