import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

/// Model hasil kalkulasi rute jalan raya resmi dari Google Routes API
class GoogleRouteResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final String formattedDuration;
  final String formattedDistance;

  GoogleRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.formattedDuration,
    required this.formattedDistance,
  });
}

/// ============================================================
/// GOOGLE ROUTES SERVICE (ROUTES API V2) — REAL ROAD NAVIGATION
/// ============================================================
/// Menghubungkan MAMPIR langsung ke Google Routes API
/// (directions/v2:computeRoutes) untuk mendapatkan rute jalan
/// turn-by-turn nyata, jarak tempuh akurat dalam meter, dan estimasi waktu berkendara.
/// ============================================================
class GoogleRoutesService {
  static const String _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  final http.Client _client;

  GoogleRoutesService({http.Client? client})
    : _client = client ?? http.Client();

  /// Menghitung rute navigasi jalan raya antara origin (lokasi GPS pengguna)
  /// dan destination (koordinat warung makan / cafe).
  /// Menggunakan Google Routes API dengan fallback otomatis ke OSRM Road Network
  /// agar rute turn-by-turn selalu mengikuti jalur jalan raya (bukan garis lurus)
  /// bahkan saat berjalan di Flutter Web (mengatasi batasan CORS).
  Future<GoogleRouteResult?> computeRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // 1. Pada platform Mobile / Native (Android/iOS), gunakan Google Routes API resmi terlebih dahulu
    if (!kIsWeb) {
      try {
        final body = jsonEncode({
          'origin': {
            'location': {
              'latLng': {
                'latitude': origin.latitude,
                'longitude': origin.longitude,
              },
            },
          },
          'destination': {
            'location': {
              'latLng': {
                'latitude': destination.latitude,
                'longitude': destination.longitude,
              },
            },
          },
          'travelMode': 'DRIVE',
        });

        final response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': ApiConfig.googleRoutesApiKey,
                'X-Goog-FieldMask':
                    'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final distanceMeters =
                (route['distanceMeters'] as num?)?.toInt() ?? 0;

            int durationSeconds = 0;
            final rawDuration = route['duration'] as String?;
            if (rawDuration != null) {
              final cleaned = rawDuration.replaceAll('s', '').trim();
              durationSeconds = int.tryParse(cleaned) ?? 0;
            }

            final polylineObj = route['polyline'] as Map<String, dynamic>?;
            final encodedPolyline =
                polylineObj?['encodedPolyline'] as String? ?? '';

            final points = decodePolyline(encodedPolyline);
            if (points.length > 1) {
              return GoogleRouteResult(
                points: points,
                distanceMeters: distanceMeters,
                durationSeconds: durationSeconds,
                formattedDuration: _formatDuration(durationSeconds),
                formattedDistance: _formatDistance(distanceMeters),
              );
            }
          }
        }
      } catch (_) {}
    }

    // 2. Gunakan OSRM Road Network (Open Source Routing Machine):
    // - Berjalan instan tanpa batasan CORS di Web / Browser
    // - Menyediakan puluhan/ratusan titik koordinat jalan raya turn-by-turn resmi
    return await _computeRouteWithOSRM(
      origin: origin,
      destination: destination,
    );
  }

  /// Fallback cerdas menggunakan Open Source Routing Machine (OSRM)
  /// Menghasilkan jalur rute jalan raya turn-by-turn resmi (mengikuti kelokan jalan)
  /// tanpa batasan CORS pada Flutter Web.
  Future<GoogleRouteResult?> _computeRouteWithOSRM({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response =
          await _client.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters =
          ((route['distance'] as num?)?.toDouble() ?? 0.0).round();
      final durationSeconds =
          ((route['duration'] as num?)?.toDouble() ?? 0.0).round();

      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.isEmpty) {
        return null;
      }

      final points = coordinates.map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      return GoogleRouteResult(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        formattedDuration: _formatDuration(durationSeconds),
        formattedDistance: _formatDistance(distanceMeters),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatDuration(int durationSeconds) {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes < 60) {
      return '$minutes mnt';
    } else {
      final hours = minutes ~/ 60;
      final remMins = minutes % 60;
      return '${hours}j ${remMins}m';
    }
  }

  static String _formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Algoritma resmi Google Polyline Decoder untuk mendekompresi encoded polyline menjadi `List<LatLng>`
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
