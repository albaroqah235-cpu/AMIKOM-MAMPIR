import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// ============================================================
/// ONBOARDING & WELCOME SCREEN — SESUAI SplashS contoh.jpeg
/// ============================================================
/// Step 1: Layar Selamat Datang (MAMPIR, Subjudul Emas, Ilustrasi, Tombol "Mulai")
/// Step 2: Atur Budget, Wilayah Purwokerto & Sekitarnya, dan Preferensi
/// Setelah selesai -> is_first_launch = false -> Masuk HomeScreen
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

  // Preferensi pengguna
  String _selectedRegion = 'Purwokerto Kota';
  int _selectedBudget = 25000;
  final Set<String> _selectedPreferences = {'WiFi', 'Colokan', 'Nongkrong'};

  late TextEditingController _budgetController;
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const List<String> _regions = [
    'Semua Wilayah',
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara (Unsoed)',
    'Sokaraja',
    'Purwokerto Timur & Sumbang',
    'Purwokerto Barat & Selatan',
  ];

  static const List<Map<String, dynamic>> _quickChips = [
    {'label': '15K', 'value': 15000},
    {'label': '25K', 'value': 25000},
    {'label': '50K', 'value': 50000},
    {'label': '75K', 'value': 75000},
    {'label': '100K', 'value': 100000},
    {'label': 'Bebas', 'value': 150000},
  ];

  static const List<String> _allPreferences = [
    'WiFi',
    'Colokan',
    'AC',
    'Parkir',
    'Nongkrong',
    'Outdoor',
    'Indoor',
    'Rooftop',
    'Romantis',
    'Ramah Hewan',
    'Musik',
  ];

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: _currencyFormatter.format(_selectedBudget),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _onBudgetSliderChanged(int val) {
    setState(() {
      _selectedBudget = val;
      if (val >= 150000) {
        _budgetController.text = 'Bebas';
      } else {
        _budgetController.text = _currencyFormatter.format(val);
      }
    });
  }

  void _onManualBudgetChanged(String val) {
    final cleanDigits = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) return;
    final int? parsed = int.tryParse(cleanDigits);
    if (parsed != null) {
      setState(() {
        _selectedBudget = parsed.clamp(5000, 200000);
      });
    }
  }

  Future<void> _handleFinishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      await _prefService.saveBudget(_selectedBudget);
      await _prefService.saveSelectedRegion(_selectedRegion);
      await _prefService.saveUserPreferences(_selectedPreferences.toList());
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
          // Mandala Batik Background Decoration
          Positioned(
            top: 0,
            right: 0,
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: MandalaOrnamentPainter(scale: 0.9),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: MandalaOrnamentPainter(scale: 0.6),
            ),
          ),

          SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcomePage(),
                _buildPreferenceSetupPage(),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60),
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

  /// Step 2: Pengaturan Awal (Wilayah, Budget & Preferensi)
  Widget _buildPreferenceSetupPage() {
    final colors = AppTheme.colors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tombol Kembali
          Row(
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
              const SizedBox(width: 8),
              Text(
                'Atur Preferensi Awal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pilih Wilayah
          Text(
            'Wilayah Utama Kamu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.searchNavy,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderNavy),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegion,
                isExpanded: true,
                dropdownColor: colors.surfaceNavy,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.gold),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region,
                    child: Text(
                      region,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (newRegion) {
                  if (newRegion != null) {
                    setState(() => _selectedRegion = newRegion);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Budget Maksimal
          Text(
            'Budget Maksimal per Orang (Rp)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // TextFormField Manual
          Container(
            decoration: BoxDecoration(
              color: colors.searchNavy,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderNavy),
            ),
            child: TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Tulis nominal budget',
                hintStyle: TextStyle(color: colors.textMuted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
              onChanged: _onManualBudgetChanged,
            ),
          ),
          const SizedBox(height: 10),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.orange,
              inactiveTrackColor: colors.borderNavy,
              thumbColor: AppTheme.gold,
              overlayColor: AppTheme.gold.withAlpha(50),
              trackHeight: 4,
            ),
            child: Slider(
              value: _selectedBudget.toDouble().clamp(5000.0, 150000.0),
              min: 5000,
              max: 150000,
              divisions: 29,
              onChanged: (val) => _onBudgetSliderChanged(val.toInt()),
            ),
          ),

          // Quick Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickChips.map((chip) {
              final val = chip['value'] as int;
              final isSelected = val >= 150000
                  ? _selectedBudget >= 150000
                  : (_selectedBudget - val).abs() < 5000;

              return GestureDetector(
                onTap: () => _onBudgetSliderChanged(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : colors.surfaceNavy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : colors.borderNavy,
                    ),
                  ),
                  child: Text(
                    chip['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : colors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // Preferensi
          Text(
            'Fasilitas & Suasana Favorit',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allPreferences.map((pref) {
              final isSelected = _selectedPreferences.contains(pref);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPreferences.remove(pref);
                    } else {
                      _selectedPreferences.add(pref);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : colors.surfaceNavy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : colors.borderNavy,
                    ),
                  ),
                  child: Text(
                    pref,
                    style: TextStyle(
                      color: isSelected ? Colors.white : colors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Tombol Selesai & Masuk Beranda
          Container(
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
                  : const Text(
                      'Simpan & Buka Beranda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
