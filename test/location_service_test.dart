import 'package:flutter_test/flutter_test.dart';
import 'package:mampir_app/models/place_model.dart';
import 'package:mampir_app/services/location_service.dart';

void main() {
  group('LocationService & GPS Accuracy Tests', () {
    final locationService = LocationService.instance;

    test('LocationService is a singleton instance', () {
      final loc1 = LocationService();
      final loc2 = LocationService.instance;
      expect(identical(loc1, loc2), isTrue);
    });

    test('calculateDistanceInKm computes geodesic distance accurately', () {
      // Alun-alun Purwokerto (-7.4244, 109.2304) to Lokawisata Baturraden (-7.3129, 109.2343)
      final dist = locationService.calculateDistanceInKm(
        startLatitude: -7.4244,
        startLongitude: 109.2304,
        endLatitude: -7.3129,
        endLongitude: 109.2343,
      );

      // Distance should be approximately 12.4 km (between 12 km and 13 km)
      expect(dist, greaterThan(12.0));
      expect(dist, lessThan(13.0));
    });

    test('formatDistanceInKm displays meters for < 1km and kilometers for >= 1km', () {
      expect(locationService.formatDistanceInKm(0.35), '350 m');
      expect(locationService.formatDistanceInKm(0.05), '50 m');
      expect(locationService.formatDistanceInKm(1.24), '1.2 km');
      expect(locationService.formatDistanceInKm(12.87), '12.9 km');
      expect(locationService.formatDistanceInKm(-1), 'Jarak tidak tersedia');
    });

    test('PlaceModel distanceInKmFrom uses high-precision Geodesic calculation', () {
      final place = PlaceModel(
        id: 'place_1',
        name: 'Lokawisata Baturraden',
        category: 'Restoran',
        address: 'Baturraden, Purwokerto',
        city: 'Baturraden',
        rating: 4.6,
        reviewCount: 1200,
        minPrice: 15000,
        maxPrice: 40000,
        imageUrl: 'https://example.com/image.jpg',
        facilities: ['Parkir Luas', 'WiFi'],
        openHours: '08:00 - 22:00',
        menuHighlights: [],
        latitude: -7.3129,
        longitude: 109.2343,
        description: 'Wisata kuliner Baturraden',
      );

      // Compare from Alun-alun Purwokerto
      final dist = place.distanceInKmFrom(-7.4244, 109.2304);
      expect(dist, greaterThan(12.0));
      expect(dist, lessThan(13.0));

      final formatted = place.formattedDistance(-7.4244, 109.2304);
      expect(formatted, contains('km'));
    });
  });
}
