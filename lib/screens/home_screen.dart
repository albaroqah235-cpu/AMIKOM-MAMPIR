import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../services/api_service.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';
import '../services/preference_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_filter_modal.dart';

import 'nearby_screen.dart';
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
  final GooglePlacesService _placesService = GooglePlacesService();

  int _currentTabIndex = 0; // 0: Beranda, 1: Cari, 2: Favorit, 3: Peta

  // Data State
  List<PlaceModel> _allPlaces = [];
  bool _isLoading = true;

  // Filter State
  String _selectedRegion = 'Purwokerto Kota';
  int _userBudget = 25000;
  Set<String> _userPreferences = {'WiFi', 'Colokan'};
  Set<String> _favoriteIds = {};
  String?
  _selectedCategory; // null = semua, or Makan, Nongkrong, Cafe, Restoran, Lainnya
  bool _isNearMeActive = false; // Mode 'Lokasi Terdekat Saya' (Feedback Client)

  // Map state
  PlaceModel? _selectedMapPlace;
  final MapController _mapTabController = MapController();
  LatLng? _userLocation;
  bool _isFetchingLocation = false;
  double? _nearbyRadiusKm = 5;
  StreamSubscription<Position>? _locationTrackingSub;

  static const List<String> _purwokertoRegions = [
    'Semua Wilayah',
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara',
    'Sokaraja',
    'Purwokerto Timur',
    'Purwokerto Barat',
    'Purwokerto Selatan',
  ];

  List<PlaceModel> get _nearbyPlaces {
    List<PlaceModel> places = List<PlaceModel>.from(_allPlaces);
    if (!_isNearMeActive &&
        _selectedRegion.isNotEmpty &&
        !_selectedRegion.toLowerCase().contains('semua')) {
      final regionKeywords = RecommendationService.getRegionKeywords(_selectedRegion);
      places.removeWhere((place) {
        final pCity = place.city.toLowerCase();
        final pAddr = place.address.toLowerCase();
        final pName = place.name.toLowerCase();
        final combined = '$pCity $pAddr $pName';
        return !regionKeywords.any((kw) => combined.contains(kw));
      });
    }

    final loc = _userLocation ?? LocationService.instance.currentLatLng;
    if (loc != null) {
      if (_nearbyRadiusKm != null) {
        final inRadius = places.where((place) {
          final distance = place.distanceInKmFrom(
            loc.latitude,
            loc.longitude,
          );
          return distance.isFinite && distance <= _nearbyRadiusKm!;
        }).toList();
        if (inRadius.isNotEmpty) {
          places = inRadius;
        }
      }
      places.sort(
        (a, b) => a
            .distanceInKmFrom(loc.latitude, loc.longitude)
            .compareTo(
              b.distanceInKmFrom(
                loc.latitude,
                loc.longitude,
              ),
            ),
      );
    }
    return places;
  }

  String _formatDistance(PlaceModel place) {
    final loc = _userLocation ?? LocationService.instance.currentLatLng;
    if (loc == null) return 'Jarak GPS belum tersedia';
    return place.formattedDistance(
      loc.latitude,
      loc.longitude,
    );
  }

  Future<void> _openNearbyFilter() async {
    final colors = AppTheme.colors(context);
    final selected = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  title: Text(
                    'Jarak tempat terdekat',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    (_userLocation != null || LocationService.instance.currentLatLng != null)
                        ? '📍 GPS aktif: Menampilkan tempat di sekitarmu'
                        : 'GPS dipakai bila lokasi sudah diizinkan',
                    style: TextStyle(
                      color: (_userLocation != null || LocationService.instance.currentLatLng != null)
                          ? AppTheme.gold
                          : colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...<double>[1, 3, 5, 10, -1].map(
                  (radius) => RadioListTile<double>(
                    value: radius,
                    // ignore: deprecated_member_use
                    groupValue: _nearbyRadiusKm ?? 5,
                    activeColor: AppTheme.orange,
                    title: Text(
                      radius < 0 ? 'Semua jarak' : '<= ${radius.toInt()} km',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // ignore: deprecated_member_use
                    onChanged: (value) => Navigator.pop(context, value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() {
        _nearbyRadiusKm = selected < 0 ? null : selected;
        _isNearMeActive = true;
      });

      if (_userLocation == null) {
        await _fetchUserGpsLocation();
      }
      await _loadNearbyGooglePlaces();

      if (mounted) {
        final radiusStr = selected < 0 ? 'semua jarak' : '<= ${selected.toInt()} km';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Menampilkan rekomendasi tempat terdekat ($radiusStr)'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadNearbyGooglePlaces() async {
    final loc = _userLocation ?? LocationService.instance.currentLatLng;
    if (loc == null) return;
    try {
      final queryRadiusKm = _nearbyRadiusKm ?? 5.0;
      final types = (_selectedCategory != null &&
              GooglePlacesService.nearbyCategoryTypes.containsKey(_selectedCategory))
          ? GooglePlacesService.nearbyCategoryTypes[_selectedCategory!]
          : GooglePlacesService.nearbyAllTypes;

      final places = await _placesService.searchNearby(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusKm: queryRadiusKm,
        includedTypes: types,
        maxResultCount: 20,
        rankPreference: 'DISTANCE',
      );

      if (mounted && places.isNotEmpty) {
        setState(() {
          final Map<String, PlaceModel> unified = {};
          for (final p in places) {
            unified[p.id] = p;
          }
          for (final p in _allPlaces) {
            if (!unified.containsKey(p.id)) {
              unified[p.id] = p;
            }
          }
          _allPlaces = unified.values.toList();
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndData();
    // Mengambil lokasi GPS di latar belakang sedini mungkin tanpa memicu spinner UI
    _initBackgroundGps();
  }

  @override
  void dispose() {
    _locationTrackingSub?.cancel();
    super.dispose();
  }

  Future<void> _initBackgroundGps() async {
    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
        if (_isNearMeActive) {
          _loadNearbyGooglePlaces();
        }
      }
    } catch (_) {}
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
        _selectedRegion = _purwokertoRegions.contains(region)
            ? region
            : (_purwokertoRegions.contains('Purwokerto Kota')
                  ? 'Purwokerto Kota'
                  : _purwokertoRegions.first);
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
      currentPlaceTypes: _selectedCategory != null ? {_selectedCategory!} : {},
      currentPreferences: _userPreferences,
    );

    if (result != null) {
      setState(() {
        _userBudget = result.budget;
        if (result.placeTypes.isNotEmpty) {
          _selectedCategory = result.placeTypes.first;
        } else {
          _selectedCategory = null;
        }
        _userPreferences = result.preferences;
      });
      await _prefService.saveBudget(result.budget);
      await _prefService.saveUserPreferences(result.preferences.toList());
    }
  }

  Future<void> _fetchUserGpsLocation({bool moveMap = false}) async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      final pos = await LocationService.instance.getCurrentLocation(
        forceRefresh: true,
      );

      if (pos != null && mounted) {
        final newLocation = LatLng(pos.latitude, pos.longitude);
        PlaceModel? nearest;
        if (_allPlaces.isNotEmpty) {
          nearest = _allPlaces.reduce((a, b) {
            final distA = a.distanceInKmFrom(pos.latitude, pos.longitude);
            final distB = b.distanceInKmFrom(pos.latitude, pos.longitude);
            return distA < distB ? a : b;
          });
        }
        setState(() {
          _userLocation = newLocation;
          _isFetchingLocation = false;
          _selectedMapPlace ??= nearest;
        });
        if (_isNearMeActive) {
          _loadNearbyGooglePlaces();
        }
        if (moveMap) {
          _mapTabController.move(_userLocation!, 15.0);
        }
      } else if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }

    // Dengarkan stream pergerakan GPS pengguna secara langsung
    _locationTrackingSub?.cancel();
    _locationTrackingSub = LocationService.instance.onLocationChanged.listen((pos) {
      if (!mounted) return;
      final liveLoc = LatLng(pos.latitude, pos.longitude);
      final distMeters = _userLocation == null
          ? double.infinity
          : Geolocator.distanceBetween(
              _userLocation!.latitude,
              _userLocation!.longitude,
              liveLoc.latitude,
              liveLoc.longitude,
            );

      // Perbarui jika bergeser lebih dari 5 meter atau pertama kali terdeteksi
      if (distMeters > 5) {
        setState(() {
          _userLocation = liveLoc;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildFavoritesTab(),
                // Tab "Dekat" membuka NearbyScreen lewat Navigator, jadi
                // placeholder ini hanya menjaga indeks IndexedStack tetap valid.
                const SizedBox.shrink(),
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
              Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Beranda')),
              Expanded(child: _buildNavItem(1, Icons.search_rounded, 'Cari')),
              Expanded(
                child: _buildNavItem(2, Icons.favorite_rounded, 'Favorit'),
              ),
              Expanded(
                child: _buildNavItem(3, Icons.near_me_rounded, 'Dekat'),
              ),
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
      onTap: () async {
        if (index == 3) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NearbyScreen()),
          );
          return;
        }
        setState(() => _currentTabIndex = index);
        // Reload favorit setiap pindah tab agar sinkronisasi selalu up-to-date
        final favs = await _prefService.getFavorites();
        if (mounted) {
          setState(() => _favoriteIds = favs.toSet());
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppTheme.gold : colors.textMuted,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.gold : colors.textMuted,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                ),
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
    // 1. Ambil tempat berdasarkan wilayah dan radius GPS (Khusus Cafe & Coffee Shop)
    var visiblePlaces = List<PlaceModel>.from(_nearbyPlaces).where((p) {
      final cat = p.category.toLowerCase();
      final name = p.name.toLowerCase();
      return cat.contains('cafe') ||
          cat.contains('coffee') ||
          name.contains('cafe') ||
          name.contains('coffee') ||
          name.contains('kopi');
    }).toList();

    // 2. Filter budget ketat jika user menetapkan budget tertentu (< 150.000)
    // Sesuai instruksi: jika budget maksimal 10k, maka HANYA tempat dengan harga <= 10k yang boleh muncul. Lebih dari 10k DILARANG muncul.
    if (_userBudget > 0 && _userBudget < 150000) {
      visiblePlaces = visiblePlaces.where((p) => p.minPrice <= _userBudget).toList();
    }

    // 3. Algoritma Rekomendasi Cerdas untuk tempat yang lolos kriteria budget & wilayah
    final recommendations = RecommendationService.getRecommendations(
      allPlaces: visiblePlaces,
      userBudget: _userBudget,
      selectedRegion: _isNearMeActive ? null : _selectedRegion,
      selectedCategory: _selectedCategory,
      userPreferences: _userPreferences.toList(),
    );

    final loc = _userLocation ?? LocationService.instance.currentLatLng;
    // Jika mode lokasi terdekat aktif, urutkan rekomendasi berdasarkan jarak terdekat dari lokasi user
    if (_isNearMeActive && loc != null) {
      recommendations.sort((a, b) {
        final distA = a.place.distanceInKmFrom(loc.latitude, loc.longitude);
        final distB = b.place.distanceInKmFrom(loc.latitude, loc.longitude);
        return distA.compareTo(distB);
      });
    }

    // 4. Tempat Populer di wilayah terpilih (selaras dengan filter wilayah, budget, dan kategori)
    List<PlaceModel> popularPlaces = List.from(visiblePlaces);
    if (_selectedCategory != null &&
        _selectedCategory!.isNotEmpty &&
        _selectedCategory != 'Semua') {
      final sel = _selectedCategory!.toLowerCase();
      bool matchesCat(PlaceModel p) {
        final cat = p.category.toLowerCase();
        final name = p.name.toLowerCase();
        final desc = p.description.toLowerCase();
        if (cat.contains(sel) || sel.contains(cat) || name.contains(sel)) return true;
        if (sel == 'cafe' || sel == 'coffee shop') {
          return cat.contains('cafe') ||
              cat.contains('kopi') ||
              name.contains('kopi') ||
              name.contains('coffee') ||
              desc.contains('cafe');
        }
        if (sel == 'warkop') {
          return cat.contains('warkop') ||
              cat.contains('warung') ||
              name.contains('warkop') ||
              name.contains('angkringan') ||
              name.contains('warmindo');
        }
        if (sel == 'restoran' || sel == 'resto' || sel == 'warung makan') {
          return cat.contains('restoran') ||
              cat.contains('resto') ||
              cat.contains('warung') ||
              name.contains('resto') ||
              name.contains('soto') ||
              name.contains('bakso') ||
              desc.contains('restoran');
        }
        if (sel == 'bakery') {
          return cat.contains('bakery') ||
              cat.contains('roti') ||
              cat.contains('kue') ||
              name.contains('roti') ||
              name.contains('bakery') ||
              name.contains('kue') ||
              name.contains('getuk') ||
              name.contains('serabi') ||
              name.contains('nopia');
        }
        if (sel == 'fast food') {
          return cat.contains('fast food') ||
              name.contains('burger') ||
              name.contains('pizza') ||
              name.contains('fried chicken') ||
              name.contains('cepat saji');
        }
        if (sel == 'bar') {
          return cat.contains('bar') || name.contains('bar') || name.contains('lounge');
        }
        return false;
      }

      popularPlaces = popularPlaces.where(matchesCat).toList();
    }
    if (_isNearMeActive && loc != null) {
      popularPlaces.sort((a, b) {
        final distA = a.distanceInKmFrom(loc.latitude, loc.longitude);
        final distB = b.distanceInKmFrom(loc.latitude, loc.longitude);
        return distA.compareTo(distB);
      });
    } else {
      popularPlaces.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    final featured = recommendations.isNotEmpty
        ? recommendations.first.place
        : (popularPlaces.isNotEmpty
            ? popularPlaces.first
            : (visiblePlaces.isNotEmpty ? visiblePlaces.first : null));

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

                  // 3. Section "Rekomendasi untuk kamu"
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
    final activeRegion = _purwokertoRegions.contains(_selectedRegion)
        ? _selectedRegion
        : _purwokertoRegions.first;

    return Row(
      children: [
        // Pin Lokasi - Klik untuk Beralih ke "Lokasi Terdekat Saya" (Feedback Client)
        GestureDetector(
          onTap: () async {
            setState(() {
              _isNearMeActive = !_isNearMeActive;
            });
            if (_isNearMeActive) {
              await _initBackgroundGps();
              if (_userLocation == null) {
                await _fetchUserGpsLocation();
              }
              await _loadNearbyGooglePlaces();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📍 Menampilkan rekomendasi lokasi cafe/resto terdekat'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _isNearMeActive
                  ? AppTheme.gold.withValues(alpha: 0.3)
                  : AppTheme.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: _isNearMeActive
                  ? Border.all(color: AppTheme.gold, width: 1.5)
                  : null,
            ),
            child: Icon(
              _isNearMeActive ? Icons.my_location : Icons.location_on,
              color: _isNearMeActive ? AppTheme.gold : AppTheme.orange,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Dropdown Wilayah ATAU Label "Lokasi Terdekat Saya"
        Expanded(
          child: _isNearMeActive
              ? GestureDetector(
                  onTap: () {
                    setState(() => _isNearMeActive = false);
                  },
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Lokasi Terdekat Saya',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: AppTheme.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceNavy,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderNavy),
                        ),
                        child: Text(
                          'Ganti',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeRegion,
                    isDense: true,
                    isExpanded: true,
                    iconSize: 0,
                    icon: const SizedBox.shrink(),
                    dropdownColor: colors.surfaceNavy,
                    selectedItemBuilder: (BuildContext ctx) {
                      return _purwokertoRegions.map((region) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                region,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colors.textPrimary,
                              size: 20,
                            ),
                          ],
                        );
                      }).toList();
                    },
                    items: _purwokertoRegions.map((region) {
                      return DropdownMenuItem<String>(
                        value: region,
                        child: Text(
                          region,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newRegion) {
                      setState(() => _isNearMeActive = false);
                      _onRegionChanged(newRegion);
                    },
                  ),
                ),
        ),

        // Lonceng Notifikasi
        IconButton(
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.gold,
            size: 24,
          ),
          tooltip: 'Notifikasi',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const NotificationScreen()),
            );
          },
        ),

        // Pengaturan
        // Profil Pengguna
        IconButton(
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.orange,
              size: 20,
            ),
          ),
          tooltip: 'Profil Pengguna',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  isRootTab: false,
                  currentRegion: _selectedRegion,
                ),
              ),
            ).then((_) => _loadPreferencesAndData());
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(
                      allPlaces: _allPlaces,
                      autoFocus: true,
                      initialBudget: _userBudget,
                      initialCategory: _selectedCategory,
                      initialRegion: _selectedRegion,
                      onFilterChanged: (b, c, r) {
                        if (mounted) {
                          setState(() {
                            if (b != null) _userBudget = b;
                            if (c != null) _selectedCategory = c;
                            if (r != null) _selectedRegion = r;
                          });
                        }
                      },
                    ),
                  ),
                );
                if (mounted) {
                  await _loadPreferencesAndData();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Cari cafe / coffee shop...',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: colors.borderNavy),
          IconButton(
            icon: Icon(
              Icons.near_me_rounded,
              color: _isNearMeActive ? AppTheme.gold : AppTheme.orange,
              size: 22,
            ),
            onPressed: () {
              if (_userLocation == null) {
                _initBackgroundGps();
              }
              _openNearbyFilter();
            },
            tooltip: 'Cafe terdekat dan radius',
          ),
          IconButton(
            icon: const Icon(
              Icons.tune_rounded,
              color: AppTheme.gold,
              size: 22,
            ),
            onPressed: _openFilterModal,
            tooltip: 'Filter Budget Cafe',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 4. Section "Rekomendasi untuk kamu"
  Widget _buildRecommendationSection(
    PlaceModel? featured,
    List<RecommendationResult> recs,
  ) {
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _isNearMeActive
                    ? 'Rekomendasi Cafe/Resto Terdekat'
                    : 'Rekomendasi untuk kamu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(
                      allPlaces: _allPlaces,
                      showAll: true,
                      initialBudget: _userBudget,
                      initialCategory: _selectedCategory,
                      initialRegion: _selectedRegion,
                      onFilterChanged: (b, c, r) {
                        if (mounted) {
                          setState(() {
                            if (b != null) _userBudget = b;
                            if (c != null) _selectedCategory = c;
                            if (r != null) _selectedRegion = r;
                          });
                        }
                      },
                    ),
                  ),
                );
                if (mounted) {
                  await _loadPreferencesAndData();
                }
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada rekomendasi tempat yang cocok dengan budget & filter kamu',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => PlaceDetailScreen(
                    place: featured,
                    userBudget: _userBudget,
                    userLocation: _userLocation ??
                        LocationService.instance.currentLatLng,
                  ),
                ),
              );
              if (mounted) {
                final favs = await _prefService.getFavorites();
                setState(() => _favoriteIds = favs.toSet());
              }
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
                            child: const Icon(
                              Icons.restaurant,
                              color: AppTheme.orange,
                              size: 50,
                            ),
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
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppTheme.gold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '${featured.rating.toStringAsFixed(1)} (${featured.formattedReviewCount})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.location_on,
                                    color: AppTheme.orange,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      _formatDistance(featured),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
            Expanded(
              child: Text(
                'Tempat Populer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(
                      allPlaces: _allPlaces,
                      showAll: true,
                      initialBudget: _userBudget,
                      initialCategory: _selectedCategory,
                      initialRegion: _selectedRegion,
                      onFilterChanged: (b, c, r) {
                        if (mounted) {
                          setState(() {
                            if (b != null) _userBudget = b;
                            if (c != null) _selectedCategory = c;
                            if (r != null) _selectedRegion = r;
                          });
                        }
                      },
                    ),
                  ),
                );
                if (mounted) {
                  await _loadPreferencesAndData();
                }
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

        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: colors.cardNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderNavy),
            ),
            child: Center(
              child: Text(
                'Tidak ada tempat dengan budget & filter yang dipilih',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            mainAxisExtent: 186,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final place = list[index];

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => PlaceDetailScreen(
                      place: place,
                      userBudget: _userBudget,
                      userLocation: _userLocation ??
                          LocationService.instance.currentLatLng,
                    ),
                  ),
                );
                if (mounted) {
                  final favs = await _prefService.getFavorites();
                  setState(() => _favoriteIds = favs.toSet());
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderNavy),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: colors.isDark ? 0.25 : 0.05,
                      ),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        place.imageUrl,
                        height: 92,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          height: 92,
                          color: colors.searchNavy,
                          child: const Icon(
                            Icons.store,
                            color: AppTheme.orange,
                          ),
                        ),
                      ),
                    ),

                    // Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                            maxLines: 2,
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
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.gold,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  '${place.rating.toStringAsFixed(1)} (${place.formattedReviewCount})',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatDistance(place),
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
    return SearchScreen(
      allPlaces: _allPlaces,
      initialBudget: _userBudget,
      initialCategory: _selectedCategory,
      initialRegion: _selectedRegion,
      onFilterChanged: (b, c, r) {
        if (mounted) {
          setState(() {
            if (b != null) _userBudget = b;
            if (c != null) _selectedCategory = c;
            if (r != null) _selectedRegion = r;
          });
        }
      },
    );
  }

  // ===========================================================================
  // TAB 3: FAVORIT (SESUAI simpanFavorit_mampir.jpeg)
  // ===========================================================================
  Widget _buildFavoritesTab() {
    final colors = AppTheme.colors(context);
    final savedPlaces = _allPlaces
        .where((place) => _favoriteIds.contains(place.id))
        .toList();

    final filtered = savedPlaces;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                          '${savedPlaces.length} cafe disimpan',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: AppTheme.gold,
                        size: 24,
                      ),
                      onPressed: _openFilterModal,
                    ),
                  ],
                ),
              ),

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
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
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
                                    userLocation: _userLocation ??
                                        LocationService.instance.currentLatLng,
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
                                border: Border.all(color: colors.borderNavy),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: colors.isDark ? 0.25 : 0.05,
                                    ),
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
                                      errorBuilder: (ctx, err, st) => Container(
                                        width: 85,
                                        height: 85,
                                        color: colors.searchNavy,
                                        child: const Icon(
                                          Icons.store,
                                          color: AppTheme.orange,
                                        ),
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
                                                overflow: TextOverflow.ellipsis,
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
                                            const Icon(
                                              Icons.star_rounded,
                                              color: AppTheme.gold,
                                              size: 16,
                                            ),
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
                                              '• ${_formatDistance(place)}',
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
  // ---------------------------------------------------------------------------
  // Tidak dipakai lagi di bottom navigation: tab "Dekat" sekarang membuka
  // NearbyScreen (Google Maps). Kode ini disimpan sebagai referensi/fallback.
  // ===========================================================================
  // ignore: unused_element
  Widget _buildMapTab() {
    final colors = AppTheme.colors(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapTabController,
          options: const MapOptions(
            initialCenter: LatLng(
              -7.3850,
              109.2380,
            ), // Poros Purwokerto - Baturraden
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
              userAgentPackageName: 'com.mampir.mampir_app',
            ),
            if (_userLocation != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation!,
                    radius: 20,
                    useRadiusInMeter: false,
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderColor: Colors.blueAccent.withValues(alpha: 0.4),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Marker GPS Lokasi Pengguna (Presisi Berada di Tengah Titik)
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Marker Tempat Kuliner
                ..._nearbyPlaces.map((place) {
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
                }),
              ],
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
                  color: Colors.black.withValues(
                    alpha: colors.isDark ? 0.3 : 0.08,
                  ),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isFetchingLocation
                        ? 'Mencari lokasi GPS kamu...'
                        : (_userLocation != null
                              ? 'Menampilkan ${_nearbyPlaces.length} tempat • GPS Terhubung'
                              : 'Menampilkan ${_allPlaces.length} tempat di $_selectedRegion'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (_isFetchingLocation)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Tombol Floating GPS Re-center
        Positioned(
          right: 16,
          bottom: _selectedMapPlace != null ? 144 : 24,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceNavy.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderNavy),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: colors.isDark ? 0.35 : 0.1,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: _isFetchingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.gold,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.gold,
                      size: 22,
                    ),
              tooltip: 'Lokasi Saya',
              onPressed: () => _fetchUserGpsLocation(moveMap: true),
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
                    color: Colors.black.withValues(
                      alpha: colors.isDark ? 0.4 : 0.12,
                    ),
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
                          _userLocation != null
                              ? '${_selectedMapPlace!.city} • ${_selectedMapPlace!.priceRange} • ${_selectedMapPlace!.distanceInKmFrom(_userLocation!.latitude, _userLocation!.longitude).toStringAsFixed(1)} km dari kamu'
                              : '${_selectedMapPlace!.city} • ${_selectedMapPlace!.priceRange}',
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
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PlaceDetailScreen(
                                      place: _selectedMapPlace!,
                                      userBudget: _userBudget,
                                      userLocation: _userLocation ??
                                          LocationService.instance.currentLatLng,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  final favs = await _prefService
                                      .getFavorites();
                                  setState(() => _favoriteIds = favs.toSet());
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.cardNavy,
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.borderNavy),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Detail',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => RouteScreen(
                                      place: _selectedMapPlace!,
                                      userLocation: _userLocation,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Rute',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _selectedMapPlace = null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
