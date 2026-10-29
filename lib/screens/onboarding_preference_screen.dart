import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// ============================================================
/// ONBOARDING & WELCOME SCREEN — SESUAI SPESIFIKASI MAMPIR
/// ============================================================
/// Halaman Selamat Datang (Logo, Judul MAMPIR, Subjudul Emas, Fitur Unggulan)
/// Ketika diklik Mulai -> Masuk ke LoginScreen
/// ============================================================
class OnboardingPreferenceScreen extends StatefulWidget {
  const OnboardingPreferenceScreen({super.key});

  @override
  State<OnboardingPreferenceScreen> createState() =>
      _OnboardingPreferenceScreenState();
}

class _OnboardingPreferenceScreenState
    extends State<OnboardingPreferenceScreen> {
  final PreferenceService _prefService = PreferenceService();

  Future<void> _handleStart() async {
    await _prefService.setFirstLaunch(false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(topSize: 280, bottomSize: 240),

          SafeArea(
            child: _buildWelcomePage(),
          ),
        ],
      ),
    );
  }

  /// Step 1: Halaman Selamat Datang (Sesuai SplashS contoh.jpeg)
  Widget _buildWelcomePage() {
    final colors = AppTheme.colors(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 8),

                  // Logo Pin & Mascot (Penuh di dalam lingkaran border tanpa space kosong & tanpa terpotong)
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.gold.withAlpha(200),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.orange.withAlpha(70),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.45,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/app_icon.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Judul Utama "MAMPIR"
                  Text(
                    'MAMPIR',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subjudul Emas
                  const Text(
                    'Makan, Ampir, Pilih, dan Rekomendasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Deskripsi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tempat makan & nongkrong terbaik di Purwokerto berdasarkan budget dan preferensi kamu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3 Kartu Fitur Unggulan (Responsif, Rapi, Tanpa Overflow)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: colors.cardNavy.withAlpha(160),
                      border: Border.all(color: colors.borderNavy),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFeatureMiniCard(
                            icon: Icons.local_cafe_rounded,
                            title: 'Cafe & Resto',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFeatureMiniCard(
                            icon: Icons.payments_rounded,
                            title: 'Pas Budget',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFeatureMiniCard(
                            icon: Icons.map_rounded,
                            title: 'Purwokerto & Sekitar',
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Tombol "Mulai"
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.orange.withAlpha(90),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Mulai',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureMiniCard({
    required IconData icon,
    required String title,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderNavy),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.orange.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.gold, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
