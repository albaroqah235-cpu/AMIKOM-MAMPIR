import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../models/place_model.dart';
import '../services/api_service.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'place_detail_screen.dart';
import 'route_screen.dart';

/// ============================================================
/// NEAR ME / TEMPAT TERDEKAT — MAMPIR
/// ============================================================
/// Menampilkan tempat makan & nongkrong di sekitar pengguna dengan:
/// - Deteksi lokasi GPS real-time + tombol perbarui lokasi
/// - Filter radius 0-1, 1-3, 3-5, 5-10, dan >10 km
/// - Filter kategori (restoran, warung, cafe, coffee shop, nongkrong, fast food)
/// - Pencarian memakai Google Places API (New) places:searchNearby
/// - Peta Google Maps dengan marker user + marker tempat
/// - Daftar kartu ala Gojek dengan detail & petunjuk arah
/// ============================================================
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const List<String> _radiusOptions = [
    '0–1 km',
    '1–3 km',
    '3–5 km',
    '5–10 km',
    '>10 km',
  ];

  static const List<String> _categoryOptions = [
    'Semua',
    'Resto',
    'Warung Makan/Warkop',
    'Cafe',
    'Bakery',
  ];

  static const Map<String, latlng.LatLng> _simulationPresets = {
    'Alun-Alun Purwokerto': latlng.LatLng(-7.4243, 109.2303),
    'GOR Satria': latlng.LatLng(-7.4120, 109.2510),
    'Kampus Unsoed': latlng.LatLng(-7.4085, 109.2450),
    'Baturraden': latlng.LatLng(-7.3150, 109.2240),
    'Sokaraja': latlng.LatLng(-7.4612, 109.2789),
    'Alun-Alun Sukabumi': latlng.LatLng(-6.9217, 106.9272),
  };

  final GooglePlacesService _placesService = GooglePlacesService();
  final LocationService _locationService = LocationService.instance;

  final MapController _mapController = MapController();
  final TextEditingController _keywordController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  StreamSubscription<Position>? _locationSubscription;

  latlng.LatLng? _userLocation;
  List<PlaceModel> _places = <PlaceModel>[];
  String _radiusFilter = '3–5 km';
  String? _selectedCategory;
  String _searchKeyword = '';
  String _sortBy = 'nearest';
  bool _loadingLocation = true;
  bool _loadingPlaces = false;
  String? _errorMessage;
  int _requestSerial = 0;
  bool _isPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _initializeNearby();
    _sheetController.addListener(() {
      if (mounted) {
        final isCollapsed = _sheetController.size <= 0.12;
        if (isCollapsed != _isPanelCollapsed) {
          setState(() => _isPanelCollapsed = isCollapsed);
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.stopTracking();
    _keywordController.dispose();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initializeNearby() async {
    await _loadCurrentLocation(forceRefresh: false);
    _listenToLocationChanges();
  }

  Future<void> _loadCurrentLocation({required bool forceRefresh}) async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = null;
    });

    final position = await _locationService.getCurrentLocation(
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (position != null) {
      setState(() {
        _userLocation = latlng.LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
        _errorMessage = null;
      });
      await _fetchNearbyPlaces();
    } else {
      // Hardcode PWT aktif: gunakan pusat Alun-Alun Purwokerto sebagai default
      setState(() {
        _userLocation = const latlng.LatLng(-7.4243, 109.2303);
        _loadingLocation = false;
        _errorMessage = null;
      });
      await _fetchNearbyPlaces();
    }
  }

  void _listenToLocationChanges() {
    _locationSubscription?.cancel();
    _locationService.startTracking(distanceFilter: 10);
    _locationSubscription = _locationService.onLocationChanged.listen((
      position,
    ) {
      if (!mounted) return;
      setState(() {
        _userLocation = latlng.LatLng(position.latitude, position.longitude);
      });
    });
  }

  void _setSimulatedLocation(latlng.LatLng target, String label) {
    setState(() {
      _userLocation = target;
      _loadingLocation = false;
      _errorMessage = null;
    });
    _fetchNearbyPlaces();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lokasi diatur ke: $label'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceNavy,
      ),
    );
  }

  Future<void> _fetchNearbyPlaces() async {
    final userLocation = _userLocation;
    if (userLocation == null) return;

    setState(() {
      _loadingPlaces = true;
      _errorMessage = null;
    });
    final requestId = ++_requestSerial;

    try {
      final types = _selectedCategory == null
          ? GooglePlacesService.nearbyAllTypes
          : GooglePlacesService.nearbyCategoryTypes[_selectedCategory!];
      final queryRadiusKm = _radiusToQueryKm(_radiusFilter);
      // Untuk radius 0–1 km gunakan DISTANCE agar urutan terdekat presisi.
      // Untuk radius 1–3 km ke atas gunakan POPULARITY agar Google Places
      // mendistribusikan hasil di seluruh lingkaran radius, bukan hanya 50 meter awal.
      final rankPref = _radiusFilter == '0–1 km' ? 'DISTANCE' : 'POPULARITY';

      List<PlaceModel> places = [];
      try {
        if (_searchKeyword.isNotEmpty) {
          // Cari nama toko / resto langsung di Google Maps via Places:searchText
          // Hardcode PWT aktif
          places = await _placesService.searchPlaces(
            _searchKeyword,
            lat: userLocation.latitude,
            lng: userLocation.longitude,
            radiusMeters: queryRadiusKm * 1000.0,
            region: 'Purwokerto',
          );
        } else {
          // Cari tempat terdekat via Google Places:searchNearby
          places = await _placesService.searchNearby(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            radiusKm: queryRadiusKm,
            includedTypes: types,
            maxResultCount: 20,
            rankPreference: rankPref,
          );
        }
      } on PlacesApiException catch (_) {
        // Fallback ke database jika Google Places offline / kuota habis
      } catch (_) {}

      // Saring KETAT: Tempat WAJIB berada dalam rentang jarak & kategori yang dipilih!
      // JANGAN PERNAH melonggarkan filter ke jarak lain atau kategori yang tidak sesuai!
      List<PlaceModel> filtered = places.where((place) {
        final distance = _distanceKm(place);
        if (!distance.isFinite) return false;

        // 1. Saring Jarak secara KETAT jika bukan pencarian kata kunci
        if (_searchKeyword.isEmpty && !_distanceInSelectedRange(distance)) {
          return false;
        }

        // 2. Saring Kategori secara KETAT (contoh: filter Cafe hanya menampilkan Cafe)
        if (!_matchesCategory(place, _selectedCategory)) {
          return false;
        }

        return true;
      }).toList();

      // Jika Google Places mengembalikan 0 tempat untuk rentang radius dan kategori ini,
      // cari di katalog Supabase MAMPIR dan saring secara KETAT pula!
      if (filtered.isEmpty) {
        final fallback = await _fetchFallbackPlaces(userLocation);
        final filteredFallback = fallback.where((place) {
          final distance = _distanceKm(place);
          if (!distance.isFinite) return false;
          if (_searchKeyword.isEmpty && !_distanceInSelectedRange(distance)) {
            return false;
          }
          if (!_matchesCategory(place, _selectedCategory)) {
            return false;
          }
          return true;
        }).toList();

        if (filteredFallback.isNotEmpty) {
          filtered = filteredFallback;
        }
      }

      _sortPlaces(filtered);

      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _places = filtered;
        _loadingPlaces = false;
        _errorMessage = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _adjustCamera());
    } catch (error) {
      if (!mounted || requestId != _requestSerial) return;
      final fallback = await _fetchFallbackPlaces(userLocation);
      final filteredFallback = fallback.where((place) {
        final distance = _distanceKm(place);
        if (!distance.isFinite) return false;
        if (_searchKeyword.isEmpty && !_distanceInSelectedRange(distance)) {
          return false;
        }
        if (!_matchesCategory(place, _selectedCategory)) {
          return false;
        }
        return true;
      }).toList();

      if (filteredFallback.isNotEmpty) {
        _sortPlaces(filteredFallback);
        setState(() {
          _places = filteredFallback;
          _loadingPlaces = false;
          _errorMessage = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _adjustCamera());
        return;
      }

      setState(() {
        _loadingPlaces = false;
        _places = <PlaceModel>[];
        _errorMessage = 'Gagal memuat tempat terdekat: $error';
      });
    }
  }

  Future<List<PlaceModel>> _fetchFallbackPlaces(
    latlng.LatLng userLocation,
  ) async {
    try {
      final dbPlaces = await ApiService().fetchPlaces();
      final filtered = dbPlaces.where((place) {
        final distance = place.distanceInKmFrom(
          userLocation.latitude,
          userLocation.longitude,
        );
        if (!distance.isFinite || !_distanceInSelectedRange(distance)) {
          return false;
        }
        if (_selectedCategory != null && _selectedCategory != 'Semua') {
          if (!_matchesCategory(place, _selectedCategory)) return false;
        }
        return true;
      }).toList();
      return filtered;
    } catch (_) {
      return [];
    }
  }

  void _sortPlaces(List<PlaceModel> places) {
    if (_sortBy == 'rating') {
      places.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        return _distanceKm(a).compareTo(_distanceKm(b));
      });
    } else {
      places.sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
    }
  }

  double _distanceKm(PlaceModel place) {
    final userLocation = _userLocation;
    if (userLocation == null) return double.infinity;
    return place.distanceInKmFrom(
      userLocation.latitude,
      userLocation.longitude,
    );
  }

  double _radiusToQueryKm(String label) {
    switch (label) {
      case '0–1 km':
        return 1;
      case '1–3 km':
        return 3;
      case '3–5 km':
        return 5;
      case '5–10 km':
        return 10;
      case '>10 km':
        return 50;
      default:
        return 5;
    }
  }

  bool _distanceInSelectedRange(double distance) {
    switch (_radiusFilter) {
      case '0–1 km':
        return distance <= 1;
      case '1–3 km':
        return distance > 1 && distance <= 3;
      case '3–5 km':
        return distance > 3 && distance <= 5;
      case '5–10 km':
        return distance > 5 && distance <= 10;
      case '>10 km':
        return distance > 10;
      default:
        return true;
    }
  }

  /// Memeriksa kesesuaian kategori tempat secara ketat
  bool _matchesCategory(PlaceModel place, String? category) {
    if (category == null || category == 'Semua') return true;
    final sel = category.trim().toLowerCase();
    final pCat = place.category.trim().toLowerCase();
    final pName = place.name.trim().toLowerCase();
    final pDesc = place.description.trim().toLowerCase();

    if (sel == 'resto' || sel == 'restoran') {
      return pCat == 'restoran' ||
          pCat == 'resto' ||
          pName.contains('resto') ||
          pName.contains('rumah makan') ||
          pName.contains('restoran') ||
          pName.contains('kitchen') ||
          pDesc.contains('restoran');
    } else if (sel.contains('warung') || sel.contains('warkop')) {
      return pCat.contains('warung') ||
          pCat.contains('warkop') ||
          pName.contains('warung') ||
          pName.contains('warkop') ||
          pName.contains('angkringan') ||
          pName.contains('warmindo') ||
          pName.contains('warteg') ||
          pName.contains('soto') ||
          pName.contains('bakso') ||
          pName.contains('mendoan');
    } else if (sel == 'cafe' || sel == 'coffee shop') {
      return pCat.contains('cafe') ||
          pCat.contains('coffee shop') ||
          pCat.contains('kopi') ||
          pName.contains('cafe') ||
          pName.contains('kafe') ||
          pName.contains('coffee') ||
          pName.contains('kopi') ||
          pDesc.contains('cafe') ||
          pDesc.contains('kafe');
    } else if (sel == 'bakery') {
      return pCat.contains('bakery') ||
          pCat.contains('roti') ||
          pName.contains('roti') ||
          pName.contains('bakery') ||
          pName.contains('kue') ||
          pName.contains('getuk') ||
          pName.contains('nopia') ||
          pName.contains('serabi') ||
          pDesc.contains('roti') ||
          pDesc.contains('kue');
    }

    return pCat.contains(sel) || pName.contains(sel);
  }

  void _adjustCamera() {
    final userLoc = _userLocation;
    if (userLoc != null) {
      _mapController.move(userLoc, 15.5);
      return;
    }
    if (_places.isNotEmpty) {
      _mapController.move(
        latlng.LatLng(_places.first.latitude, _places.first.longitude),
        15.0,
      );
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 18.5) {
      _mapController.move(_mapController.camera.center, currentZoom + 1.0);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 3.0) {
      _mapController.move(_mapController.camera.center, currentZoom - 1.0);
    }
  }

  void _recenterToUser() {
    final userLoc = _userLocation;
    if (userLoc != null) {
      _mapController.move(userLoc, 15.5);
    } else {
      _loadCurrentLocation(forceRefresh: true);
    }
  }

  List<Marker> _buildFlutterMapMarkers() {
    final markers = <Marker>[];

    // Marker pengguna (biru)
    final userLocation = _userLocation;
    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation,
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
      );
    }

    // Marker tempat (oranye)
    for (final place in _places) {
      final point = latlng.LatLng(place.latitude, place.longitude);
      markers.add(
        Marker(
          point: point,
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _showPlaceInfo(place),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.warmGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
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
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Future<void> _refreshLocation() async {
    await _loadCurrentLocation(forceRefresh: true);
  }

  void _onCategoryChanged(String? category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    if (_userLocation != null) {
      _fetchNearbyPlaces();
    }
  }

  void _onRadiusChanged(String radius) {
    if (_radiusFilter == radius) return;
    setState(() => _radiusFilter = radius);
    if (_userLocation != null) {
      _fetchNearbyPlaces();
    }
  }

  void _onSortChanged(String sort) {
    if (_sortBy == sort) return;
    setState(() {
      _sortBy = sort;
      final list = List<PlaceModel>.from(_places);
      _sortPlaces(list);
      _places = list;
    });
  }

  latlng.LatLng? _widgetUserLocation() {
    final userLocation = _userLocation;
    if (userLocation == null) return null;
    return latlng.LatLng(userLocation.latitude, userLocation.longitude);
  }

  void _openDetail(PlaceModel place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: place,
          userLocation: _widgetUserLocation(),
        ),
      ),
    );
  }

  void _openRoute(PlaceModel place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RouteScreen(place: place, userLocation: _widgetUserLocation()),
      ),
    );
  }

  Future<void> _showPlaceInfo(PlaceModel place) async {
    final colors = AppTheme.colors(context);
    final distance = _distanceKm(place);

    _mapController.move(
      latlng.LatLng(place.latitude, place.longitude),
      16,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.borderNavy,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: _placeImageWidget(place, colors),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${place.category} • ${place.priceRange}',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppTheme.gold,
                                  size: 16,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  place.rating > 0
                                      ? place.rating.toStringAsFixed(1)
                                      : 'Belum ada rating',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.near_me_rounded,
                                  color: colors.textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDistanceKm(distance),
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
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppTheme.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.address,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (place.openHours.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppTheme.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place.openHours,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openDetail(place);
                          },
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Lihat Detail'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.borderNavy),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openRoute(place);
                          },
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Petunjuk Arah'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeImageWidget(PlaceModel place, AppColors colors) {
    final imageUrl = place.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return Container(
        color: colors.searchNavy,
        child: const Icon(
          Icons.restaurant_rounded,
          color: AppTheme.orange,
          size: 30,
        ),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: colors.searchNavy,
        child: const Icon(
          Icons.restaurant_rounded,
          color: AppTheme.orange,
          size: 30,
        ),
      ),
    );
  }

  String _formatDistanceKm(double distance) {
    if (!distance.isFinite) return 'Jarak tidak tersedia';
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }

  String _shortOpenStatus(String openHours) {
    final lower = openHours.toLowerCase();
    if (lower.contains('buka sekarang')) return 'Buka sekarang';
    if (lower.contains('tutup sekarang')) return 'Tutup sekarang';
    return openHours.split(' • ').first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          _buildMap(),
          _buildMapControls(colors),
          _buildBottomPanel(colors),
          _buildTopOverlay(colors),
          if (_loadingLocation || _loadingPlaces)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppTheme.gold,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControls(AppColors colors) {
    return Positioned(
      right: 14,
      top: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapControlBtn(
            icon: Icons.my_location_rounded,
            tooltip: 'Pusatkan Lokasi Saya',
            onTap: _recenterToUser,
            colors: colors,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceNavy.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderNavy),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: colors.isDark ? 0.35 : 0.10,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Perbesar Peta (Zoom In)',
                  onTap: _zoomIn,
                  colors: colors,
                  isGrouped: true,
                ),
                Container(
                  width: 28,
                  height: 1,
                  color: colors.borderNavy,
                ),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Perkecil Peta (Zoom Out)',
                  onTap: _zoomOut,
                  colors: colors,
                  isGrouped: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required AppColors colors,
    bool isGrouped = false,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isGrouped ? 8 : 12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: AppTheme.gold,
            size: 20,
          ),
        ),
      ),
    );

    if (isGrouped) {
      return Tooltip(message: tooltip, child: button);
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceNavy.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderNavy),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colors.isDark ? 0.35 : 0.10,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(message: tooltip, child: button),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation ??
            const latlng.LatLng(-7.4244, 109.2304),
        initialZoom: 15.5,
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
          markers: _buildFlutterMapMarkers(),
        ),
      ],
    );
  }

  Widget _buildTopOverlay(AppColors colors) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    colors: colors,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceNavy.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderNavy),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: colors.isDark ? 0.30 : 0.08,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: AppTheme.gold,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tempat Terdekat',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _loadingLocation
                                      ? 'Mendeteksi lokasi kamu...'
                                      : _userLocation == null
                                      ? 'Lokasi belum tersedia'
                                      : '${_places.length} tempat • $_radiusFilter',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _circleButton(
                            icon: Icons.my_location_rounded,
                            colors: colors,
                            loading: _loadingLocation || _loadingPlaces,
                            onTap: _refreshLocation,
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            tooltip: 'Pilih Titik Lokasi Simulasi',
                            icon: const Icon(
                              Icons.location_city_rounded,
                              color: AppTheme.gold,
                              size: 20,
                            ),
                            color: colors.surfaceNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colors.borderNavy),
                            ),
                            onSelected: (key) {
                              final target = _simulationPresets[key];
                              if (target != null) {
                                _setSimulatedLocation(target, key);
                              }
                            },
                            itemBuilder: (context) => _simulationPresets.keys.map((key) {
                              return PopupMenuItem<String>(
                                value: key,
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _buildSearchField(colors),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildCategoryFilters(colors),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildRadiusAndSortFilters(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.surfaceNavy.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderNavy),
      ),
      child: TextField(
        controller: _keywordController,
        style: TextStyle(color: colors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari toko di Google Maps (misal: Mixue, KFC, Gacoan...)',
          hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.gold),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _keywordController.clear();
                    setState(() => _searchKeyword = '');
                    _fetchNearbyPlaces();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: (value) {
          setState(() => _searchKeyword = value.trim());
          _fetchNearbyPlaces();
        },
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required AppColors colors,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Material(
      color: colors.surfaceNavy,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: loading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold,
                  ),
                )
              : Icon(icon, color: AppTheme.gold, size: 20),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(AppColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categoryOptions.map((label) {
          final value = label == 'Semua' ? null : label;
          return _buildFilterChip(
            label: label,
            selected: _selectedCategory == value,
            colors: colors,
            onSelected: () => _onCategoryChanged(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRadiusAndSortFilters(AppColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._radiusOptions.map(
            (label) => _buildFilterChip(
              label: label,
              selected: _radiusFilter == label,
              colors: colors,
              onSelected: () => _onRadiusChanged(label),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.only(right: 8, left: 2),
            color: colors.borderNavy,
          ),
          _buildFilterChip(
            label: 'Terdekat',
            selected: _sortBy == 'nearest',
            colors: colors,
            onSelected: () => _onSortChanged('nearest'),
          ),
          _buildFilterChip(
            label: 'Rating Tertinggi',
            selected: _sortBy == 'rating',
            colors: colors,
            onSelected: () => _onSortChanged('rating'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required AppColors colors,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
          color: selected ? Colors.black : colors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: AppTheme.gold,
        backgroundColor: colors.surfaceNavy.withValues(alpha: 0.96),
        side: BorderSide(color: selected ? AppTheme.gold : colors.borderNavy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildBottomPanel(AppColors colors) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.45,
      minChildSize: 0.08,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.08, 0.45, 0.88],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: colors.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_sheetController.isAttached) {
                      if (_sheetController.size > 0.12) {
                        _sheetController.animateTo(
                          0.08,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _sheetController.animateTo(
                          0.45,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderNavy,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _loadingPlaces
                                    ? 'Mencari tempat terdekat...'
                                    : 'Daftar Tempat (${_places.length})',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_loadingPlaces)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.gold,
                                  ),
                                ),
                              ),
                            // Tombol chevron untuk menutup/membuka panel daftar tempat
                            IconButton(
                              icon: Icon(
                                _isPanelCollapsed
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: colors.textSecondary,
                                size: 26,
                              ),
                              onPressed: () {
                                if (_sheetController.isAttached) {
                                  if (_sheetController.size > 0.12) {
                                    _sheetController.animateTo(
                                      0.08,
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  } else {
                                    _sheetController.animateTo(
                                      0.45,
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                }
                              },
                              tooltip: _isPanelCollapsed ? 'Buka Daftar' : 'Tutup Daftar',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadingPlaces)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(colors),
                )
              else if (_places.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(colors),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPlaceCard(_places[index], colors),
                      childCount: _places.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _focusPlaceOnMap(PlaceModel place) {
    if (_sheetController.isAttached && _sheetController.size > 0.45) {
      _sheetController.animateTo(
        0.45,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
    _mapController.move(
      latlng.LatLng(place.latitude, place.longitude),
      16.5,
    );
    _showPlaceInfo(place);
  }

  Widget _buildPlaceCard(PlaceModel place, AppColors colors) {
    final distance = _distanceKm(place);
    final status = _shortOpenStatus(place.openHours);
    final statusLower = status.toLowerCase();
    final statusColor = statusLower.contains('buka')
        ? Colors.greenAccent
        : statusLower.contains('tutup')
        ? Colors.redAccent
        : colors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderNavy),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _focusPlaceOnMap(place),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: _placeImageWidget(place, colors),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${place.category} • ${_formatDistanceKm(distance)}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.gold,
                          size: 15,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          place.rating > 0
                              ? '${place.rating.toStringAsFixed(1)} '
                                    '(${place.formattedReviewCount})'
                              : 'Belum ada rating',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    if (place.openHours.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openDetail(place),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.borderNavy),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Lihat Detail',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRoute(place),
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text(
                    'Petunjuk Arah',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildEmptyState(AppColors colors) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_searching_rounded,
              size: 44,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada tempat ditemukan',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah filter jarak/kategori atau perbarui lokasi kamu.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isPanelCollapsed = true);
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(
                    0.08,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                }
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              label: const Text('Tutup Panel & Lihat Peta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.gold),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColors colors) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.orange,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadingLocation || _loadingPlaces
                  ? null
                  : () {
                      if (_userLocation == null) {
                        _loadCurrentLocation(forceRefresh: true);
                      } else {
                        _fetchNearbyPlaces();
                      }
                    },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
            ),
            if (_userLocation == null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Buka Pengaturan Izin'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
              ),
              const SizedBox(height: 14),
              Text(
                'Atau gunakan simulasi titik lokasi (Sukabumi / Purwokerto):',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _simulationPresets.entries.map((entry) {
                  return ActionChip(
                    label: Text(entry.key),
                    labelStyle: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colors.cardNavy,
                    side: BorderSide(color: colors.borderNavy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => _setSimulatedLocation(entry.value, entry.key),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
