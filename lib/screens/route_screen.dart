import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';
import '../services/google_routes_service.dart';
import '../theme/app_theme.dart';

/// ============================================================
/// ROUTE & MAP SCREEN — SESUAI petadanRute_mampir.jpeg
/// ============================================================
/// Menampilkan:
/// 1. Jalur rute jalan raya resmi (Google Routes API)
/// 2. Marker titik awal (Lokasi Anda) dan pin maskot tujuan
/// 3. Estimasi waktu & jarak rute nyata tercepat
/// 4. Tombol "Mulai Navigasi" yang terintegrasi dengan Google Maps
/// ============================================================
class RouteScreen extends StatefulWidget {
  final PlaceModel place;
  final LatLng? userLocation;

  const RouteScreen({super.key, required this.place, this.userLocation});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final MapController _mapController;
  late LatLng _destPos;
  late LatLng _userPos;
  List<LatLng> _routePoints = [];
  bool _isLocating = true;
  bool _isLoadingRoute = false;
  String? _realDuration;
  String? _realDistance;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _destPos = LatLng(widget.place.latitude, widget.place.longitude);
    // Jika ada lokasi dari parameter, gunakan langsung
    if (widget.userLocation != null) {
      _userPos = widget.userLocation!;
      _isLocating = false;
      _buildRoute();
    } else {
      // Titik awal sementara di dekat Purwokerto / lokasi tujuan
      _userPos = LatLng(
        widget.place.latitude - 0.009,
        widget.place.longitude - 0.008,
      );
      _buildRoute();
      _fetchUserLocation();
    }
  }

  Future<void> _buildRoute() async {
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);

    try {
      final routeService = GoogleRoutesService();
      final result = await routeService.computeRoute(
        origin: _userPos,
        destination: _destPos,
      );

      if (result != null && mounted) {
        setState(() {
          _routePoints = result.points;
          _realDuration = result.formattedDuration;
          _realDistance = result.formattedDistance;
          _isLoadingRoute = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = [_userPos, _destPos];
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      final p = position;
      if (p != null && mounted) {
        setState(() {
          _userPos = LatLng(p.latitude, p.longitude);
          _isLocating = false;
        });
        await _buildRoute();
        _mapController.move(
          LatLng(
            (_userPos.latitude + _destPos.latitude) / 2,
            (_userPos.longitude + _destPos.longitude) / 2,
          ),
          14.2,
        );
      } else if (mounted) {
        setState(() => _isLocating = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _launchGoogleMaps() async {
    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _recenter() {
    _mapController.move(_destPos, 14.5);
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final distKm = widget.place.distanceInKmFrom(
      _userPos.latitude,
      _userPos.longitude,
    );
    final int estMinutes = (distKm * 3.5 + 2).round().clamp(3, 45);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // 1. Peta OpenStreetMap dengan FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (_userPos.latitude + _destPos.latitude) / 2,
                (_userPos.longitude + _destPos.longitude) / 2,
              ),
              initialZoom: 14.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mampir.mampir_app',
              ),

              // Polyline Rute (Warna Oranye Hangat)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.5,
                    color: AppTheme.orange,
                  ),
                ],
              ),

              // Marker Lokasi Anda & Tempat Tujuan
              MarkerLayer(
                markers: [
                  // Marker 1: Lokasi Anda (Titik Biru Berdenyut)
                  Marker(
                    point: _userPos,
                    width: 80,
                    height: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceNavy,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: const Text(
                            'Lokasi Anda',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Marker 2: Tempat Tujuan (Pin Maskot MAMPIR)
                  Marker(
                    point: _destPos,
                    width: 90,
                    height: 90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceNavy,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.orange),
                          ),
                          child: Text(
                            widget.place.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.orange.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Transform.scale(
                              scale: 1.35,
                              alignment: const Alignment(0, -0.04),
                              child: Image.asset(
                                'assets/images/app_icon.jpeg',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Header Atas: Tombol Back & Card Alamat Rute
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.surfaceNavy.withValues(
                          alpha: 0.9,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back, color: colors.iconColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceNavy.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.borderNavy),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: colors.isDark ? 0.3 : 0.08,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isLocating
                                        ? 'Mencari GPS...'
                                        : 'Lokasi Anda',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_isLocating) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4.5),
                                child: Container(
                                  width: 1,
                                  height: 14,
                                  color: colors.borderNavy,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.place.name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Tombol Floating Kontrol Peta di Sebelah Kanan
          Positioned(
            right: 16,
            bottom: 230,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(icon: Icons.add, onTap: _zoomIn),
                const SizedBox(height: 8),
                _buildMapControlBtn(icon: Icons.remove, onTap: _zoomOut),
              ],
            ),
          ),

          // 4. Bottom Card Informasi Rute & Tombol Mulai Navigasi
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderNavy),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: colors.isDark ? 0.5 : 0.1,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Estimasi Rute
                  Row(
                    children: [
                      Text(
                        'Rute Tercepat • ${_realDuration ?? '$estMinutes mnt'} (${_realDistance ?? widget.place.formattedDistance()})',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_isLoadingRoute) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.gold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Info Tempat
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.place.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            width: 60,
                            height: 60,
                            color: colors.searchNavy,
                            child: const Icon(
                              Icons.store,
                              color: AppTheme.orange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.place.name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: AppTheme.gold,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.place.rating.toStringAsFixed(1)} (${widget.place.formattedReviewCount})',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${widget.place.category}',
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
                  const SizedBox(height: 16),

                  // Tombol "Mulai Navigasi"
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.orange.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _launchGoogleMaps,
                      icon: const Icon(
                        Icons.near_me_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Mulai Navigasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = AppTheme.colors(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceNavy.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderNavy),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.gold, size: 22),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
