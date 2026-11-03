import 'dart:convert';
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
  Future<GoogleRouteResult?> computeRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
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

      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': ApiConfig.googleRoutesApiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;

      // Parsing durasi (format Google Routes: e.g. "199s" atau detik)
      int durationSeconds = 0;
      final rawDuration = route['duration'] as String?;
      if (rawDuration != null) {
        final cleaned = rawDuration.replaceAll('s', '').trim();
        durationSeconds = int.tryParse(cleaned) ?? 0;
      }

      final polylineObj = route['polyline'] as Map<String, dynamic>?;
      final encodedPolyline = polylineObj?['encodedPolyline'] as String? ?? '';

      final points = decodePolyline(encodedPolyline);
      if (points.isEmpty) {
        return null;
      }

      // Format durasi: e.g. "4 mnt" atau "1 jam 12 mnt"
      String formattedDuration;
      final minutes = (durationSeconds / 60).ceil();
      if (minutes < 60) {
        formattedDuration = '$minutes mnt';
      } else {
        final hours = minutes ~/ 60;
        final remMins = minutes % 60;
        formattedDuration = '${hours}j ${remMins}m';
      }

      // Format jarak: e.g. "850 m" atau "2.4 km"
      String formattedDistance;
      if (distanceMeters < 1000) {
        formattedDistance = '$distanceMeters m';
      } else {
        formattedDistance = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
      }

      return GoogleRouteResult(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        formattedDuration: formattedDuration,
        formattedDistance: formattedDistance,
      );
    } catch (_) {
      return null;
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
