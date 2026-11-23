import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mampir_app/config/api_config.dart';
import 'package:mampir_app/screens/nearby_screen.dart';
import 'package:mampir_app/services/api_service.dart';
import 'package:mampir_app/services/google_places_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearbyScreen & Google Maps Nearby Feature Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ApiConfig is fully configured with Supabase and Google API Keys', () {
      expect(ApiConfig.isConfigured, isTrue);
      expect(ApiConfig.isGoogleConfigured, isTrue);
      expect(ApiConfig.supabaseUrl, contains('oztqhofaadjldjrowrgy.supabase.co'));
      expect(ApiConfig.googlePlacesApiKey, isNotEmpty);
      expect(ApiConfig.googleRoutesApiKey, isNotEmpty);
    });

    test('GooglePlacesService has correct category type mappings', () {
      expect(GooglePlacesService.nearbyAllTypes, contains('restaurant'));
      expect(GooglePlacesService.nearbyAllTypes, contains('cafe'));
      expect(GooglePlacesService.nearbyAllTypes, contains('coffee_shop'));
      expect(GooglePlacesService.nearbyAllTypes, contains('fast_food_restaurant'));

      final catMap = GooglePlacesService.nearbyCategoryTypes;
      expect(catMap['Restoran'], contains('restaurant'));
      expect(catMap['Warung Makan'], contains('restaurant'));
      expect(catMap['Cafe'], contains('cafe'));
      expect(catMap['Coffee Shop'], contains('coffee_shop'));
      expect(catMap['Tempat Nongkrong'], contains('cafe'));
      expect(catMap['Fast Food'], contains('fast_food_restaurant'));
    });

    test('Distance calculation correctly sorts and filters by 5 distance buckets', () async {
      final places = await ApiService().fetchPlaces();
      expect(places.length, equals(25));

      // User at Alun-Alun Purwokerto (-7.4243, 109.2303)
      const uLat = -7.4243;
      const uLng = 109.2303;

      // 0–1 km
      final bucket0to1 = places.where((p) {
        final d = p.distanceInKmFrom(uLat, uLng);
        return d <= 1.0;
      }).toList();

      // 1–3 km
      final bucket1to3 = places.where((p) {
        final d = p.distanceInKmFrom(uLat, uLng);
        return d > 1.0 && d <= 3.0;
      }).toList();

      // 3–5 km
      final bucket3to5 = places.where((p) {
        final d = p.distanceInKmFrom(uLat, uLng);
        return d > 3.0 && d <= 5.0;
      }).toList();

      // 5–10 km (e.g. Sokaraja)
      final bucket5to10 = places.where((p) {
        final d = p.distanceInKmFrom(uLat, uLng);
        return d > 5.0 && d <= 10.0;
      }).toList();

      // >10 km (e.g. Baturraden)
      final bucketOver10 = places.where((p) {
        final d = p.distanceInKmFrom(uLat, uLng);
        return d > 10.0;
      }).toList();

      // Verify authentic places span all buckets
      expect(bucket0to1.isNotEmpty, isTrue, reason: 'Must have places in 0–1 km');
      expect(bucket1to3.isNotEmpty, isTrue, reason: 'Must have places in 1–3 km');
      expect(bucket3to5.isNotEmpty, isTrue, reason: 'Must have places in 3–5 km');
      expect(bucket5to10.isNotEmpty, isTrue, reason: 'Must have places in 5–10 km (e.g. Sokaraja)');
      expect(bucketOver10.isNotEmpty, isTrue, reason: 'Must have places in >10 km (e.g. Baturraden)');
    });

    testWidgets('NearbyScreen renders UI with all 5 radius filters, categories, and map', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NearbyScreen(),
        ),
      );
      await tester.pump();

      // Check header
      expect(find.text('Tempat Terdekat'), findsOneWidget);
      expect(find.byIcon(Icons.near_me_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Check all 5 radius filter chips
      expect(find.text('0–1 km'), findsOneWidget);
      expect(find.text('1–3 km'), findsOneWidget);
      expect(find.text('3–5 km'), findsOneWidget);
      expect(find.text('5–10 km'), findsOneWidget);
      expect(find.text('>10 km'), findsOneWidget);

      // Check sort options
      expect(find.text('Terdekat'), findsOneWidget);
      expect(find.text('Rating Tertinggi'), findsOneWidget);

      // Check categories
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Resto'), findsOneWidget);
      expect(find.text('Warung Makan/Warkop'), findsOneWidget);
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('Bakery'), findsOneWidget);
    });
  });
}
