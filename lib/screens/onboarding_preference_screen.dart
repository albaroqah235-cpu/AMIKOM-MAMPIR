import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// ============================================================
/// ONBOARDING & WELCOME SCREEN — SESUAI SPESIFIKASI MAMPIR
/// ============================================================
/// Step 1: Layar Selamat Datang (Logo, Judul MAMPIR, Subjudul Emas, Fitur Unggulan)
/// Step 2: Pilih Wilayah Utama Kamu (Kartu Interaktif & Tersinkronisasi Otomatis)
/// Setelah selesai -> is_first_launch = false -> Masuk LoginScreen
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
  final PageController _pageController = PageController();

  bool _isLoading = false;

  // Wilayah utama terpilih
  String _selectedRegion = 'Purwokerto Kota';

  static const List<Map<String, dynamic>> _regionOptions = [
    {
      'name': 'Purwokerto Kota',
      'desc': 'Pusat kota, alun-alun & kuliner legendaris',
      'icon': Icons.location_city_rounded,
    },
    {
      'name': 'Baturraden',
      'desc': 'Wisata alam sejuk & cafe lereng gunung',
      'icon': Icons.forest_rounded,
    },
    {
      'name': 'Purwokerto Utara (Unsoed)',
      'desc': 'Kawasan kampus & nongkrong mahasiswa',
      'icon': Icons.school_rounded,
    },
    {
      'name': 'Sokaraja',
      'desc': 'Sentra kuliner getuk goreng & soto khas',
      'icon': Icons.restaurant_rounded,
    },
    {
      'name': 'Purwokerto Timur & Sumbang',
      'desc': 'Area asri, cafe estetik & kuliner santai',
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'name': 'Purwokerto Barat',
      'desc': 'Akses stasiun, kuliner malam & sentra jajanan',
      'icon': Icons.directions_railway_rounded,
    },
    {
      'name': 'Purwokerto Selatan',
      'desc': 'Akses terminal & tempat makan keluarga',
      'icon': Icons.explore_rounded,
    },
    {
      'name': 'Semua Wilayah',
      'desc': 'Jelajahi seluruh tempat kuliner se-Banyumas',
      'icon': Icons.map_rounded,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleFinishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      await _prefService.saveSelectedRegion(_selectedRegion);
      await _prefService.setFirstLaunch(false);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcomePage(),
                _buildRegionSelectionPage(),
              ],
            ),
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

                  // Logo Pin & Mascot
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.gold.withAlpha(160),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.orange.withAlpha(60),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.36,
                          alignment: const Alignment(0, -0.04),
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
                      onPressed: () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.orange.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.gold, size: 22),
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
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: Halaman Pilih Wilayah Utama Kamu
  Widget _buildRegionSelectionPage() {
    final colors = AppTheme.colors(context);
    return Column(
      children: [
        // Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Wilayah Utama',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Area utama untuk rekomendasi kuliner kamu',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Daftar Kartu Pilihan Wilayah Interaktif
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            physics: const BouncingScrollPhysics(),
            itemCount: _regionOptions.length,
            itemBuilder: (context, index) {
              final opt = _regionOptions[index];
              final isSelected = _selectedRegion == opt['name'];

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedRegion = opt['name'] as String);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.gold.withAlpha(28)
                        : colors.cardNavy.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.gold : colors.borderNavy,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.orange.withAlpha(35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.orange
                              : colors.surfaceNavy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          color: isSelected ? Colors.white : AppTheme.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['name'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppTheme.gold
                                    : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              opt['desc'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.gold
                                : colors.borderNavy,
                            width: 2,
                          ),
                          color: isSelected
                              ? AppTheme.gold
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Tombol Lanjut ke Masuk / Daftar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orange.withAlpha(90),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleFinishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lanjut ke Masuk / Daftar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
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
        ),
      ],
    );
  }
}
