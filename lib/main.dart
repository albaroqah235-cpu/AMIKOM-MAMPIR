import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_preference_screen.dart';
import 'services/preference_service.dart';
import 'theme/app_theme.dart';

/// ============================================================
/// MAIN.DART — ENTRY POINT APLIKASI MAMPIR
/// ============================================================
/// MAMPIR: Makan, Ampir, Pilih, dan Rekomendasi
/// Kuliner & Nongkrong • Kota Purwokerto & Sekitarnya (Baturraden, Sokaraja)
/// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedTheme = await PreferenceService().getThemeMode();
  AppTheme.setThemeFromString(savedTheme);
  runApp(const MampirApp());
}

class MampirApp extends StatelessWidget {
  const MampirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'MAMPIR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            final isDark = themeMode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                : themeMode == ThemeMode.dark;
            return Container(
              color: isDark ? Colors.black : const Color(0xFFE2E8F0),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ClipRect(child: child),
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

/// ============================================================
/// SPLASH SCREEN — SESUAI SPESIFIKASI #3 & splash screen.jpeg
/// ============================================================
/// - Background Deep Navy #0D1326
/// - Fade-in animasi halus 2.5 detik
/// - Cek is_first_launch via PreferenceService:
///   * True  -> OnboardingPreferenceScreen
///   * False -> HomeScreen
/// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final PreferenceService _prefService = PreferenceService();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    _startTimerAndRoute();
  }

  Future<void> _startTimerAndRoute() async {
    // Intersep token Google OAuth dari URL (untuk web SSO flow)
    if (kIsWeb) {
      try {
        final fragment = Uri.base.fragment;
        final query = Uri.base.queryParameters;
        final hasToken =
            fragment.contains('access_token=') ||
            query.containsKey('access_token');
        if (hasToken) {
          final tokenStr =
              fragment.isNotEmpty ? fragment : (query['access_token'] ?? '');
          if (tokenStr.isNotEmpty) {
            final processed = await _processUrlToken(tokenStr);
            if (processed && mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (context, anim, secondAnim) =>
                      const HomeScreen(),
                  transitionsBuilder: (context, anim, secondAnim, child) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                ),
              );
              return;
            }
          }
        }
      } catch (_) {}
    }

    // Jalankan timer 2.5 detik
    await Future.delayed(const Duration(milliseconds: 2500));

    final isFirst = await _prefService.isFirstLaunch();
    final isLoggedIn = await _prefService.isLoggedIn();

    if (!mounted) return;

    final Widget targetScreen;
    if (isFirst) {
      targetScreen = const OnboardingPreferenceScreen();
    } else if (!isLoggedIn) {
      targetScreen = const LoginScreen();
    } else {
      targetScreen = const HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim, secondAnim) => targetScreen,
        transitionsBuilder: (context, anim, secondAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Memproses token OAuth dari URL fragment/query setelah Google SSO redirect
  Future<bool> _processUrlToken(String tokenStr) async {
    try {
      String? accessToken;
      // Parse fragment format: access_token=...&expires_in=...
      if (tokenStr.contains('=')) {
        final params = Uri.splitQueryString(tokenStr);
        accessToken = params['access_token'];
      } else {
        accessToken = tokenStr;
      }
      if (accessToken == null || accessToken.isEmpty) return false;

      // Decode JWT payload
      final parts = accessToken.split('.');
      if (parts.length != 3) return false;

      String payload = parts[1];
      // Tambah padding Base64 jika perlu
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedBytes = base64Url.decode(payload);
      final decodedStr = String.fromCharCodes(decodedBytes);
      final Map<String, dynamic> claims = jsonDecode(decodedStr);

      final email = claims['email'] as String? ?? '';
      final name =
          (claims['user_metadata']?['full_name'] as String?) ??
          (claims['user_metadata']?['name'] as String?) ??
          email.split('@').first;

      if (email.isEmpty) return false;

      await _prefService.login(
        name: name,
        email: email,
        isGuest: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(topSize: 320, bottomSize: 280),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Splash Logo Gambar (dari splash screen.jpeg)
                      Container(
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                          maxHeight: 320,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/splash_logo.jpeg',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  'assets/images/app_icon.jpeg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, st) => const Icon(
                                    Icons.restaurant_menu_rounded,
                                    size: 100,
                                    color: AppTheme.orange,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
