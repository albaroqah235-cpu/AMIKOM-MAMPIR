import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';
import '../services/preference_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_filter_modal.dart';
import 'place_detail_screen.dart';

/// ============================================================
/// SEARCH SCREEN / TAB — SESUAI riwayat pencarian_mampir.jpeg
/// & hasil pencarian_mampir.jpeg
/// ============================================================
class SearchScreen extends StatefulWidget {
  final List<PlaceModel> allPlaces;
  final String? initialQuery;
  final bool autoFocus;
  final bool showAll;
  final int? initialBudget;
  final String? initialCategory;
  final String? initialRegion;
  final void Function(int? budget, String? category, String? region)?
  onFilterChanged;

  const SearchScreen({
    super.key,
    required this.allPlaces,
    this.initialQuery,
    this.autoFocus = false,
    this.showAll = false,
    this.initialBudget,
    this.initialCategory,
    this.initialRegion,
    this.onFilterChanged,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final PreferenceService _preferenceService = PreferenceService();
  final GooglePlacesService _placesService = GooglePlacesService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _history = [];
  List<PlaceModel> _searchResults = [];
  bool _hasSearched = false;
  bool _isLoadingGooglePlaces = false;
  int _sortOption = 0; // 0: Terdekat, 1: Rating Tertinggi
  LatLng? _userLocation;

  // Filter state
  int _currentBudget = 25000;
  Set<String> _currentPlaceTypes = {};
  Set<String> _currentPreferences = {'WiFi'};
  Set<String> _favoriteIds = {};
  String _currentRegion = 'Purwokerto Kota';

  @override
  void initState() {
    super.initState();

    if (widget.initialBudget != null) {
      _currentBudget = widget.initialBudget!;
    }
    if (widget.initialRegion != null && widget.initialRegion!.isNotEmpty) {
      _currentRegion = widget.initialRegion!;
    }
    if (widget.initialCategory != null &&
        widget.initialCategory!.isNotEmpty &&
        widget.initialCategory != 'Semua') {
      _currentPlaceTypes = {widget.initialCategory!};
    }

    _loadInitialData();

    if (widget.showAll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAllPlaces());
    } else if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    } else if (widget.autoFocus) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _loadInitialData() async {
    final history = await _preferenceService.getSearchHistory();
    final budget = widget.initialBudget ?? await _preferenceService.getBudget();
    final prefs = await _preferenceService.getUserPreferences();
    final favs = await _preferenceService.getFavorites();
    final region =
        widget.initialRegion ?? await _preferenceService.getSelectedRegion();

    _userLocation = LocationService.instance.currentLatLng;

    LocationService.instance.getCurrentLocation().then((p) {
      if (p != null && mounted) {
        setState(() => _userLocation = LatLng(p.latitude, p.longitude));
      }
    });

    if (mounted) {
      setState(() {
        _history = history;
        _currentBudget = budget;
        _currentRegion = region;
        if (prefs.isNotEmpty) {
          _currentPreferences = prefs.toSet();
        }
        _favoriteIds = favs.toSet();
      });
    }
  }

  void _sortResults(List<PlaceModel> list) {
    final lat = _userLocation?.latitude ?? -7.4244;
    final lng = _userLocation?.longitude ?? 109.2302;
    if (_sortOption == 0) {
      list.sort(
        (a, b) => a
            .distanceInKmFrom(lat, lng)
            .compareTo(b.distanceInKmFrom(lat, lng)),
      );
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
  }

  void _showAllPlaces() {
    // Tampilkan semua tempat tanpa batasan saat showAll=true (Lihat Semua)
    List<PlaceModel> results = List.from(widget.allPlaces);
    _sortResults(results);
    setState(() {
      _hasSearched = true;
      _searchResults = results;
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (widget.showAll) {
        _showAllPlaces();
        return;
      }
      if (!_hasSearched) {
        setState(() {
          _hasSearched = false;
          _searchResults = [];
        });
        return;
      }
    }

    // Simpan kata kunci ke riwayat jika ada
    if (trimmed.isNotEmpty) {
      await _preferenceService.addSearchKeyword(trimmed);
      _loadHistoryOnly();
    }

    setState(() {
      _hasSearched = true;
      _isLoadingGooglePlaces = trimmed.isNotEmpty;
    });

    List<PlaceModel> googlePlaces = [];
    if (trimmed.isNotEmpty) {
      try {
        googlePlaces = await _placesService.searchPlaces(
          trimmed,
          lat: _userLocation?.latitude,
          lng: _userLocation?.longitude,
          region: _currentRegion,
        );
      } catch (_) {}
    }

    // Saring kandidat tempat lokal berdasarkan wilayah
    List<PlaceModel> localCandidates = widget.allPlaces;
    if (_currentRegion.isNotEmpty && !_currentRegion.toLowerCase().contains('semua')) {
      final regionKeywords = RecommendationService.getRegionKeywords(_currentRegion);
      localCandidates = localCandidates.where((place) {
        final pCity = place.city.toLowerCase();
        final pAddr = place.address.toLowerCase();
        final pName = place.name.toLowerCase();
        final combined = '$pCity $pAddr $pName';
        return regionKeywords.any((kw) => combined.contains(kw));
      }).toList();
    }

    // Saring kandidat tempat lokal secara ketat jika user mengetik kata kunci
    if (trimmed.isNotEmpty) {
      final queryLower = trimmed.toLowerCase();
      final tokens = queryLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      localCandidates = localCandidates.where((p) {
        final pName = p.name.toLowerCase();
        final pCat = p.category.toLowerCase();
        final pAddr = p.address.toLowerCase();
        final pDesc = p.description.toLowerCase();
        final pTags = p.tags.map((t) => t.toLowerCase()).join(' ');
        final pMenu = p.menuHighlights.map((m) => m.name.toLowerCase()).join(' ');
        final combined = '$pName $pCat $pAddr $pDesc $pTags $pMenu';

        if (combined.contains(queryLower)) return true;
        return tokens.every((token) => combined.contains(token));
      }).toList();
    }

    // Saring budget ketat jika filter budget aktif (< 150.000)
    // Sesuai instruksi: jika budget maksimal 10k, tempat dengan minPrice > 10k DILARANG muncul
    if (_currentBudget > 0 && _currentBudget < 150000) {
      localCandidates = localCandidates.where((p) => p.minPrice <= _currentBudget).toList();
      if (googlePlaces.isNotEmpty) {
        googlePlaces = googlePlaces.where((p) => p.minPrice <= _currentBudget).toList();
      }
    }

    // Jalankan Algoritma Rekomendasi Cerdas untuk tempat lokal yang lolos kriteria
    final recs = RecommendationService.getRecommendations(
      allPlaces: localCandidates,
      userBudget: _currentBudget,
      userInputQuery: trimmed,
      userPreferences: _currentPreferences.toList(),
    );
    final localMatches = recs.map((r) => r.place).toList();

    // Gabungkan tempat dari Google Places (nyata & live) dan tempat lokal
    final Map<String, PlaceModel> unifiedMap = {};
    for (final p in googlePlaces) {
      unifiedMap[p.name.toLowerCase().trim()] = p;
    }
    for (final p in localMatches) {
      final key = p.name.toLowerCase().trim();
      if (!unifiedMap.containsKey(key)) {
        unifiedMap[key] = p;
      }
    }

    List<PlaceModel> results = unifiedMap.values.toList();

    // Pastikan hasil akhir mematuhi batas budget maksimal (< 150.000)
    if (_currentBudget > 0 && _currentBudget < 150000) {
      results = results.where((p) => p.minPrice <= _currentBudget).toList();
    }

    // Saring berdasarkan jenis tempat (Kategori Google Maps) jika ada filter aktif
    if (_currentPlaceTypes.isNotEmpty) {
      final filtered = results.where((p) {
        return _currentPlaceTypes.any((type) {
          final t = type.toLowerCase();
          final cat = p.category.toLowerCase();
          final name = p.name.toLowerCase();
          if (cat.contains(t) || t.contains(cat)) return true;
          if (name.contains(t)) return true;
          if (t == 'warung makan' && (cat.contains('warung') || cat.contains('restoran') || name.contains('warung') || name.contains('soto') || name.contains('bakso') || name.contains('makan'))) return true;
          if (t == 'coffee shop' && (cat.contains('cafe') || cat.contains('kopi') || name.contains('kopi') || name.contains('coffee'))) return true;
          if (t == 'warkop' && (cat.contains('warkop') || name.contains('warkop') || name.contains('kopi'))) return true;
          if (t == 'fast food' && (cat.contains('fast food') || name.contains('burger') || name.contains('pizza') || name.contains('fried chicken') || name.contains('cepat saji'))) return true;
          if (t == 'bakery' && (cat.contains('bakery') || cat.contains('roti') || name.contains('roti') || name.contains('kue') || name.contains('getuk') || name.contains('serabi'))) return true;
          if (t == 'bar' && (cat.contains('bar') || name.contains('bar') || name.contains('lounge'))) return true;
          return p.facilities.any((f) => f.toLowerCase().contains(t));
        });
      }).toList();
      results = filtered;
    }

    // Urutkan berdasarkan sortOption (0: Terdekat via GPS / Alun-alun, 1: Rating Tertinggi)
    _sortResults(results);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoadingGooglePlaces = false;
      });
    }
  }

  Future<void> _loadHistoryOnly() async {
    final history = await _preferenceService.getSearchHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _deleteHistoryItem(String item) async {
    await _preferenceService.removeSearchKeyword(item);
    await _loadHistoryOnly();
  }

  Future<void> _clearAllHistory() async {
    await _preferenceService.clearSearchHistory();
    await _loadHistoryOnly();
  }

  Future<void> _openFilterModal() async {
    final result = await BudgetFilterModal.show(
      context,
      currentBudget: _currentBudget,
      currentPlaceTypes: _currentPlaceTypes,
      currentPreferences: _currentPreferences,
    );

    if (result != null) {
      await _preferenceService.saveBudget(result.budget);
      await _preferenceService.saveUserPreferences(result.preferences.toList());
      setState(() {
        _currentBudget = result.budget;
        _currentPlaceTypes = result.placeTypes;
        _currentPreferences = result.preferences;
      });
      widget.onFilterChanged?.call(
        result.budget,
        result.placeTypes.isNotEmpty ? result.placeTypes.first : null,
        _currentRegion,
      );
      _performSearch(_searchController.text);
    }
  }

  Future<void> _toggleFavorite(String placeId) async {
    final isFav = await _preferenceService.toggleFavorite(placeId);
    setState(() {
      if (isFav) {
        _favoriteIds.add(placeId);
      } else {
        _favoriteIds.remove(placeId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Search Bar & Filter
                _buildSearchHeader(),

                // Konten: Riwayat Pencarian vs Hasil Pencarian
                Expanded(
                  child: _hasSearched
                      ? _buildSearchResultsView()
                      : _buildSearchHistoryView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    final colors = AppTheme.colors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: colors.iconColor),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.searchNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderNavy),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search, color: colors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari tempat makan / nongkrong...',
                        hintStyle: TextStyle(color: colors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colors.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _hasSearched = false);
                      },
                    ),
                  Container(width: 1, height: 22, color: colors.borderNavy),
                  IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.gold,
                      size: 20,
                    ),
                    onPressed: _openFilterModal,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan Riwayat Pencarian (riwayat pencarian_mampir.jpeg)
  Widget _buildSearchHistoryView() {
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Pencarian',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_history.isNotEmpty)
                GestureDetector(
                  onTap: _clearAllHistory,
                  child: const Text(
                    'Hapus semua',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // History Items List
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 54,
                        color: colors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada riwayat pencarian',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardNavy,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderNavy),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: colors.isDark ? 0.25 : 0.04,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: AppTheme.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _searchController.text = item;
                                _performSearch(item);
                              },
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _deleteHistoryItem(item),
                            child: Icon(
                              Icons.close,
                              color: colors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Tampilan Hasil Pencarian (hasil pencarian_mampir.jpeg)
  Widget _buildSearchResultsView() {
    final colors = AppTheme.colors(context);

    // Filter Chips Info string (misal: "Rp 25K • WiFi • Nongkrong")
    final budgetStr = _currentBudget >= 150000
        ? 'Bebas'
        : 'Rp ${(_currentBudget ~/ 1000)}K';
    final parts = [budgetStr];
    if (_currentPlaceTypes.isNotEmpty) {
      parts.add(_currentPlaceTypes.first);
    }
    final filterChipsInfo = parts.join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Sort Pills: Terdekat vs Rating Tertinggi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildSortPill('Terdekat', 0),
              const SizedBox(width: 10),
              _buildSortPill('Rating Tertinggi', 1),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Pilihan filtermu chip info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Pilihan filtermu: $filterChipsInfo',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List Hasil Pencarian
        Expanded(
          child: _isLoadingGooglePlaces
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.gold),
                      const SizedBox(height: 16),
                      Text(
                        'Mencari di Google Maps...',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Menghubungkan ke warung makan asli di Purwokerto',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 54,
                        color: colors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada tempat yang sesuai',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _openFilterModal,
                        child: const Text(
                          'Ubah Filter Budget',
                          style: TextStyle(color: AppTheme.gold),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    final isFav = _favoriteIds.contains(place.id);

                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PlaceDetailScreen(
                              place: place,
                              userBudget: _currentBudget,
                              userLocation: _userLocation ??
                                  LocationService.instance.currentLatLng,
                            ),
                          ),
                        );
                        if (mounted) {
                          final favs = await _preferenceService.getFavorites();
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
                            // Thumbnail Foto
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                place.imageUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Container(
                                  width: 90,
                                  height: 90,
                                  color: colors.searchNavy,
                                  child: const Icon(
                                    Icons.restaurant,
                                    color: AppTheme.orange,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Detail Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Kategori Badge & Favorite
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          place.category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _toggleFavorite(place.id),
                                        child: Icon(
                                          isFav
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFav
                                              ? AppTheme.orange
                                              : colors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Place Name
                                  Text(
                                    place.name,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),

                                  // Price Range
                                  Text(
                                    place.priceRange,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Rating, Reviews & Distance
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.orange,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        place.formattedDistance(
                                          _userLocation?.latitude,
                                          _userLocation?.longitude,
                                        ),
                                        style: TextStyle(
                                          color: colors.textSecondary,
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSortPill(String label, int optionIndex) {
    final colors = AppTheme.colors(context);
    final isSelected = _sortOption == optionIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _sortOption = optionIndex);
        if (_hasSearched && _searchController.text.trim().isEmpty) {
          setState(() {
            _sortResults(_searchResults);
          });
        } else {
          _performSearch(_searchController.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : colors.surfaceNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : colors.borderNavy,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
