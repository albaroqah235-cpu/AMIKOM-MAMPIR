import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// ============================================================
/// REGION SELECTION SCREEN — PILIH WILAYAH UTAMA SETELAH LOGIN
/// ============================================================
/// Ditampilkan tepat setelah pengguna berhasil login / register.
/// Wilayah yang dipilih otomatis tersinkronisasi ke Beranda & Pengaturan.
/// ============================================================
class RegionSelectionScreen extends StatefulWidget {
  const RegionSelectionScreen({super.key});

  @override
  State<RegionSelectionScreen> createState() => _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends State<RegionSelectionScreen> {
  final PreferenceService _prefService = PreferenceService();
  bool _isLoading = false;
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
      'name': 'Purwokerto Utara',
      'desc': 'Kawasan kampus & nongkrong mahasiswa',
      'icon': Icons.school_rounded,
    },
    {
      'name': 'Sokaraja',
      'desc': 'Sentra kuliner getuk goreng & soto khas',
      'icon': Icons.restaurant_rounded,
    },
    {
      'name': 'Purwokerto Timur',
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
  void initState() {
    super.initState();
    _loadCurrentRegion();
  }

  Future<void> _loadCurrentRegion() async {
    final current = await _prefService.getSelectedRegion();
    if (mounted && current.isNotEmpty) {
      setState(() => _selectedRegion = current);
    }
  }

  Future<void> _handleConfirmRegion() async {
    setState(() => _isLoading = true);
    try {
      // 1. Simpan wilayah terpilih
      await _prefService.saveSelectedRegion(_selectedRegion);

      // 2. Jika user adalah tamu, perbarui nama & email tamu sesuai wilayah
      if (await _prefService.isGuest()) {
        final guestName = PreferenceService.formatGuestName(_selectedRegion);
        final guestEmail = PreferenceService.formatGuestEmail(_selectedRegion);
        await _prefService.login(
          name: guestName,
          email: guestEmail,
          isGuest: true,
        );
      }

      if (!mounted) return;

      // 3. Masuk ke Beranda (HomeScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Wilayah Utama',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pilih area kuliner & tempat nongkrong yang ingin kamu jelajahi terlebih dahulu. Pilihan ini dapat diubah kapan saja di Beranda.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Daftar Kartu Pilihan Wilayah
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
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

                // Tombol Simpan & Buka Beranda
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
                      onPressed: _isLoading ? null : _handleConfirmRegion,
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
                                  'Simpan & Buka Beranda',
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
            ),
          ),
        ],
      ),
    );
  }
}

