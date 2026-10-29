import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../services/api_service.dart';
import '../services/preference_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_filter_modal.dart';

import 'notification_screen.dart';
import 'place_detail_screen.dart';
import 'route_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// ============================================================
/// HOME SCREEN — SESUAI beranda.jpeg & SPESIFIKASI #8
/// ============================================================
/// Fitur Lengkap:
/// - Header: Pin Oranye + Dropdown Purwokerto & Sekitarnya + Lonceng Notifikasi + Pengaturan
/// - Search Bar + Filter Modal
/// - 5 Tombol Kategori Bulat Gradasi: Makan, Nongkrong, Cafe, Restoran, Lainnya
/// - Rekomendasi untuk kamu (Featured Card & Carousel Cerdas)
/// - Tempat Populer (2-Column Grid)
/// - 4-Tab Bottom Navigation: Beranda, Cari, Favorit, Peta
/// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final PreferenceService _prefService = PreferenceService();

  int _currentTabIndex = 0; // 0: Beranda, 1: Cari, 2: Favorit, 3: Peta

  // Data State
  List<PlaceModel> _allPlaces = [];
  bool _isLoading = true;

  // Filter State
  String _selectedRegion = 'Purwokerto Kota';
  int _userBudget = 25000;
  Set<String> _userPreferences = {'WiFi', 'Colokan'};
  Set<String> _favoriteIds = {};
  String? _selectedCategory; // null = semua, or Makan, Nongkrong, Cafe, Restoran, Lainnya

  // Map state
  PlaceModel? _selectedMapPlace;

  // Favorit tab category filter
  String _selectedFavCategory = 'Semua';

  static const List<String> _purwokertoRegions = [
    'Semua Wilayah',
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara (Unsoed)',
    'Sokaraja',
    'Purwokerto Timur & Sumbang',
    'Purwokerto Barat & Selatan',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndData();
  }

  Future<void> _loadPreferencesAndData() async {
    setState(() => _isLoading = true);

    final region = await _prefService.getSelectedRegion();
    final budget = await _prefService.getBudget();
    final prefs = await _prefService.getUserPreferences();
    final favs = await _prefService.getFavorites();

    final places = await _apiService.fetchPlaces();

    if (mounted) {
      setState(() {
        _selectedRegion = region;
        _userBudget = budget;
        if (prefs.isNotEmpty) _userPreferences = prefs.toSet();
        _favoriteIds = favs.toSet();
        _allPlaces = places;
        _isLoading = false;
      });
    }
  }

  Future<void> _onRegionChanged(String? newRegion) async {
    if (newRegion == null) return;
    await _prefService.saveSelectedRegion(newRegion);

    if (await _prefService.isGuest()) {
      final guestName = PreferenceService.formatGuestName(newRegion);
      final guestEmail = PreferenceService.formatGuestEmail(newRegion);
      await _prefService.login(
        name: guestName,
        email: guestEmail,
        isGuest: true,
      );
    }

    if (mounted) {
      setState(() => _selectedRegion = newRegion);
    }
  }

  Future<void> _toggleFavorite(String placeId) async {
    final isFav = await _prefService.toggleFavorite(placeId);
    setState(() {
      if (isFav) {
        _favoriteIds.add(placeId);
      } else {
        _favoriteIds.remove(placeId);
      }
    });
  }

  Future<void> _openFilterModal() async {
    final result = await BudgetFilterModal.show(
      context,
      currentBudget: _userBudget,
      currentPreferences: _userPreferences,
    );

    if (result != null) {
      setState(() {
        _userBudget = result.budget;
        _userPreferences = result.preferences;
      });
      await _prefService.saveBudget(result.budget);
      await _prefService.saveUserPreferences(result.preferences.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            )
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildFavoritesTab(),
                _buildMapTab(),
                SettingsScreen(
                  isRootTab: true,
                  currentRegion: _selectedRegion,
                  key: ValueKey('settings_$_selectedRegion'),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION BAR (5 TABS DENGAN DUKUNGAN TEMA)
  // ===========================================================================
  Widget _buildBottomNavigationBar() {
    final colors = AppTheme.colors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bottomNavBg,
        border: Border(
          top: BorderSide(color: colors.bottomNavBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Beranda'),
              _buildNavItem(1, Icons.search_rounded, 'Cari'),
              _buildNavItem(2, Icons.favorite_rounded, 'Favorit'),
              _buildNavItem(3, Icons.map_outlined, 'Peta'),
              _buildNavItem(4, Icons.person_rounded, 'Akun'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final colors = AppTheme.colors(context);
    final isActive = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTabIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppTheme.gold : colors.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.gold : colors.textMuted,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: BERANDA (SESUAI beranda.jpeg)
  // ===========================================================================
  Widget _buildHomeTab() {
    // Jalankan Algoritma Rekomendasi Cerdas Hybrid
    final recommendations = RecommendationService.getRecommendations(
      allPlaces: _allPlaces,
      userBudget: _userBudget,
      selectedRegion: _selectedRegion,
      selectedCategory: _selectedCategory,
      userPreferences: _userPreferences.toList(),
    );

    // Tempat Populer di wilayah terpilih
    List<PlaceModel> popularPlaces = _allPlaces.where((p) {
      if (_selectedRegion.isNotEmpty &&
          !_selectedRegion.toLowerCase().contains('semua')) {
        final regClean = _selectedRegion.split('(')[0].trim().toLowerCase();
        final pCity = p.city.toLowerCase();
        final pAddr = p.address.toLowerCase();
        if (!pCity.contains(regClean) && !pAddr.contains(regClean)) {
          return false;
        }
      }
      return true;
    }).toList();
    if (popularPlaces.isEmpty) {
      popularPlaces = List.from(_allPlaces);
    }
    popularPlaces.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

    final featured = recommendations.isNotEmpty
        ? recommendations.first.place
        : (_allPlaces.isNotEmpty ? _allPlaces.first : null);

    return Stack(
      children: [
        // Background Mandala & Batik Multi-Sudut
        const AppBackgroundOrnament(),

        SafeArea(
          child: RefreshIndicator(
            color: AppTheme.gold,
            backgroundColor: AppTheme.surfaceNavy,
            onRefresh: _loadPreferencesAndData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // 1. Header: Pin Oranye + Dropdown Purwokerto & Sekitarnya + Lonceng
                  _buildTopHeader(),
                  const SizedBox(height: 18),

                  // 2. Search Bar + Filter Button
                  _buildSearchBar(),
                  const SizedBox(height: 22),

                  // 3. Section Kategori
                  _buildCategorySection(),
                  const SizedBox(height: 26),

                  // 4. Section "Rekomendasi untuk kamu"
                  _buildRecommendationSection(featured, recommendations),
                  const SizedBox(height: 26),

                  // 5. Section "Tempat Populer"
                  _buildPopularSection(popularPlaces),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 1. Top Header: Pin Oranye + Region Dropdown + Bell + Setting Icon
  Widget _buildTopHeader() {
    final colors = AppTheme.colors(context);
    return Row(
      children: [
        // Pin Oranye
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.orange.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on,
            color: AppTheme.orange,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),

        // Dropdown Wilayah
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRegion,
              isDense: true,
              dropdownColor: colors.surfaceNavy,
              icon: Icon(Icons.keyboard_arrow_down,
                  color: colors.textPrimary, size: 20),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              items: _purwokertoRegions.map((region) {
                return DropdownMenuItem<String>(
                  value: region,
                  child: Text(
                    region,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _onRegionChanged,
            ),
          ),
        ),

        // Lonceng Notifikasi
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              color: AppTheme.gold, size: 26),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const NotificationScreen()),
            );
          },
        ),

        // Pengaturan
        IconButton(
          icon: Icon(Icons.settings_outlined,
              color: colors.iconColor, size: 24),
          onPressed: () {
            setState(() => _currentTabIndex = 4);
          },
        ),
      ],
    );
  }

  /// 2. Search Bar + Filter Button (Sesuai mockup)
  Widget _buildSearchBar() {
    final colors = AppTheme.colors(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.searchNavy,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.borderNavy),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search, color: colors.textMuted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(
                      allPlaces: _allPlaces,
                      autoFocus: true,
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Cari tempat makan / nongkrong...',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: colors.borderNavy,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.gold, size: 22),
            onPressed: _openFilterModal,
            tooltip: 'Filter Budget & Preferensi',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 3. Section Kategori: 5 Tombol Lingkaran Bergradasi Emas-Oranye
  Widget _buildCategorySection() {
    final colors = AppTheme.colors(context);
    final categories = [
      {'name': 'Cafe', 'icon': Icons.local_cafe_rounded},
      {'name': 'Warkop', 'icon': Icons.emoji_food_beverage_rounded},
      {'name': 'Restoran', 'icon': Icons.restaurant_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: categories.map((cat) {
            final name = cat['name'] as String;
            final isSelected = _selectedCategory == name;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedCategory == name) {
                    _selectedCategory = null;
                  } else {
                    _selectedCategory = name;
                  }
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppTheme.warmGradient
                          : AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.orange.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      cat['icon'] as IconData,
                      size: 26,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? AppTheme.gold : colors.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 4. Section "Rekomendasi untuk kamu"
  Widget _buildRecommendationSection(
      PlaceModel? featured, List<RecommendationResult> recs) {
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rekomendasi untuk kamu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(allPlaces: _allPlaces),
                  ),
                );
              },
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (featured == null)
          const Center(
            child: Text(
              'Belum ada rekomendasi tempat',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => PlaceDetailScreen(
                    place: featured,
                    userBudget: _userBudget,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                // Featured Card Container
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderNavy),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        Image.network(
                          featured.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            color: AppTheme.surfaceNavy,
                            child: const Icon(Icons.restaurant,
                                color: AppTheme.orange, size: 50),
                          ),
                        ),

                        // Dark Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),

                        // Text Details
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                featured.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${featured.category} • ${featured.priceRange}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: AppTheme.gold, size: 18),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${featured.rating.toStringAsFixed(1)} (${featured.formattedReviewCount})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.location_on,
                                      color: AppTheme.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    featured.formattedDistance(),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tombol Hati (Favorit)
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _favoriteIds.contains(featured.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _favoriteIds.contains(featured.id)
                            ? AppTheme.orange
                            : Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _toggleFavorite(featured.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 5. Section "Tempat Populer" (2-Column Grid)
  Widget _buildPopularSection(List<PlaceModel> places) {
    final colors = AppTheme.colors(context);
    final list = places.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tempat Populer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(allPlaces: _allPlaces),
                  ),
                );
              },
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final place = list[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => PlaceDetailScreen(
                      place: place,
                      userBudget: _userBudget,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderNavy),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        place.imageUrl,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          height: 100,
                          color: colors.searchNavy,
                          child: const Icon(Icons.store, color: AppTheme.orange),
                        ),
                      ),
                    ),

                    // Info
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${place.category} • ${place.priceRange}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppTheme.gold, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${place.rating.toStringAsFixed(1)} (${place.formattedReviewCount})',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                place.formattedDistance(),
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: CARI (MENYEDIAKAN SEARCHSCREEN LENGKAP DENGAN RIWAYAT & FILTER)
  // ===========================================================================
  Widget _buildSearchTab() {
    return SearchScreen(allPlaces: _allPlaces);
  }

  // ===========================================================================
  // TAB 3: FAVORIT (SESUAI simpanFavorit_mampir.jpeg)
  // ===========================================================================
  Widget _buildFavoritesTab() {
    final colors = AppTheme.colors(context);
    final savedPlaces = _allPlaces
        .where((place) => _favoriteIds.contains(place.id))
        .toList();

    final filtered = _selectedFavCategory == 'Semua'
        ? savedPlaces
        : savedPlaces
            .where((p) => p.category
                .toLowerCase()
                .contains(_selectedFavCategory.toLowerCase()))
            .toList();

    return Stack(
      children: [
        // Background Mandala & Batik Multi-Sudut
        const AppBackgroundOrnament(),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Favorit
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${savedPlaces.length} tempat disimpan',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded,
                          color: AppTheme.gold, size: 24),
                      onPressed: _openFilterModal,
                    ),
                  ],
                ),
              ),

              // Filter Chips: Semua, Cafe, Restoran
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['Semua', 'Cafe', 'Warkop', 'Restoran'].map((cat) {
                    final isSel = _selectedFavCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFavCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSel ? AppTheme.primaryGradient : null,
                          color: isSel ? null : colors.surfaceNavy,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? Colors.transparent : colors.borderNavy,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSel ? Colors.white : colors.textSecondary,
                            fontWeight:
                                isSel ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Daftar Kartu Favorit
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colors.surfaceNavy,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.borderNavy),
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                size: 54,
                                color: AppTheme.orange,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada tempat favorit',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sentuh ikon hati untuk menyimpan tempat makan favoritmu.',
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final place = filtered[index];

                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => PlaceDetailScreen(
                                    place: place,
                                    userBudget: _userBudget,
                                  ),
                                ),
                              );
                              final favs = await _prefService.getFavorites();
                              if (mounted) {
                                setState(() => _favoriteIds = favs.toSet());
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.cardNavy,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: colors.borderNavy),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: colors.isDark ? 0.25 : 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      place.imageUrl,
                                      width: 85,
                                      height: 85,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) =>
                                          Container(
                                        width: 85,
                                        height: 85,
                                        color: colors.searchNavy,
                                        child: const Icon(Icons.store,
                                            color: AppTheme.orange),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                place.name,
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  _toggleFavorite(place.id),
                                              child: const Icon(
                                                Icons.favorite,
                                                color: AppTheme.orange,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded,
                                                color: AppTheme.gold,
                                                size: 16),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${place.rating.toStringAsFixed(1)} (${place.formattedReviewCount})',
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '• ${place.formattedDistance()}',
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${place.category} • ${place.priceRange}',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: PETA (OPENSTREETMAP VIA FLUTTER_MAP)
  // ===========================================================================
  Widget _buildMapTab() {
    final colors = AppTheme.colors(context);
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(-7.3850, 109.2380), // Poros Purwokerto - Baturraden
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mampir.mampir_app',
            ),
            MarkerLayer(
              markers: _allPlaces.map((place) {
                final isSelected = _selectedMapPlace?.id == place.id;
                return Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: isSelected ? 52 : 42,
                  height: isSelected ? 52 : 42,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedMapPlace = place);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? AppTheme.warmGradient
                            : AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Header Banner Peta
        Positioned(
          top: 14,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceNavy.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderNavy),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    size: 18, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menampilkan ${_allPlaces.length} tempat di Purwokerto & Sekitarnya',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Preview Card saat Marker Peta Ditekan
        if (_selectedMapPlace != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.orange),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.4 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _selectedMapPlace!.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                        width: 70,
                        height: 70,
                        color: colors.searchNavy,
                        child: const Icon(Icons.store, color: AppTheme.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedMapPlace!.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_selectedMapPlace!.city} • ${_selectedMapPlace!.priceRange}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PlaceDetailScreen(
                                      place: _selectedMapPlace!,
                                      userBudget: _userBudget,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.cardNavy,
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(
                                    color: colors.borderNavy),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Detail',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => RouteScreen(
                                        place: _selectedMapPlace!),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Rute',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                    onPressed: () =>
                        setState(() => _selectedMapPlace = null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
