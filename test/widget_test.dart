import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mampir_app/main.dart';
import 'package:mampir_app/screens/home_screen.dart';
import 'package:mampir_app/screens/route_screen.dart';
import 'package:mampir_app/screens/search_screen.dart';
import 'package:mampir_app/screens/settings_screen.dart';
import 'package:mampir_app/services/api_service.dart';
import 'package:mampir_app/services/auth_service.dart';
import 'package:mampir_app/services/preference_service.dart';
import 'package:mampir_app/services/recommendation_service.dart';
import 'package:mampir_app/widgets/budget_filter_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MAMPIR app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MampirApp());
    // Verify the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);

    // Fast-forward past the splash timer
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('ApiService returns 25 authentic places for Purwokerto & Sekitarnya', () async {
    final apiService = ApiService();
    final places = await apiService.fetchPlaces();

    expect(places.length, equals(25));

    // Verify places include key regions like Purwokerto Kota, Baturraden, Sokaraja, Unsoed
    final cities = places.map((p) => p.city).toSet();
    expect(cities.contains('Purwokerto Kota'), isTrue);
    expect(cities.contains('Baturraden'), isTrue);
    expect(cities.contains('Sokaraja'), isTrue);
    expect(cities.contains('Purwokerto Utara'), isTrue);
    expect(cities.contains('Purwokerto Timur'), isTrue);
    expect(cities.contains('Purwokerto Barat'), isTrue);
    expect(cities.contains('Purwokerto Selatan'), isTrue);

    // Verify all latitudes are in Purwokerto - Baturraden region (~ -7.31 to -7.47)
    for (final p in places) {
      expect(p.latitude, inInclusiveRange(-7.50, -7.25));
      expect(p.longitude, inInclusiveRange(109.15, 109.35));
    }
  });

  test('All places strictly belong to categories Cafe, Warkop, or Restoran', () async {
    final apiService = ApiService();
    final places = await apiService.fetchPlaces();

    const allowedCategories = {'Cafe', 'Warkop', 'Restoran'};
    for (final p in places) {
      expect(allowedCategories.contains(p.category), isTrue,
          reason: 'Place ${p.name} has unexpected category: ${p.category}');
    }

    final categories = places.map((p) => p.category).toSet();
    expect(categories, equals(allowedCategories));
  });

  test('RecommendationService filters Purwokerto sub-regions accurately', () async {
    final apiService = ApiService();
    final places = await apiService.fetchPlaces();

    // Test Baturraden recommendations
    final btrRecs = RecommendationService.getRecommendations(
      allPlaces: places,
      userBudget: 50000,
      selectedRegion: 'Baturraden',
    );
    expect(btrRecs.isNotEmpty, isTrue);
    expect(btrRecs.any((r) => r.place.city.contains('Baturraden')), isTrue);

    // Test Sokaraja recommendations
    final skrRecs = RecommendationService.getRecommendations(
      allPlaces: places,
      userBudget: 50000,
      selectedRegion: 'Sokaraja',
    );
    expect(skrRecs.isNotEmpty, isTrue);
    expect(skrRecs.any((r) => r.place.city.contains('Sokaraja')), isTrue);
  });

  test('PreferenceService getSearchHistory returns empty list when raw is null', () async {
    SharedPreferences.setMockInitialValues({});
    final prefService = PreferenceService();

    final history = await prefService.getSearchHistory();
    expect(history, isEmpty);

    // After adding a search keyword, it should be recorded
    await prefService.addSearchKeyword('Kopi Keprok');
    final updated = await prefService.getSearchHistory();
    expect(updated, equals(['Kopi Keprok']));
  });

  testWidgets('SettingsScreen has direct notification toggle and no rating/share', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'setting_notification_enabled': true,
      'user_name': 'Penjelajah Test',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(isRootTab: true),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Direct Switch toggle for Notifikasi exists
    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    // Verify 'Beri Rating MAMPIR' and 'Bagikan Aplikasi' are NOT present
    expect(find.text('Beri Rating MAMPIR'), findsNothing);
    expect(find.text('Bagikan Aplikasi'), findsNothing);
  });

  test('AuthService performs signUp, signIn, OTP recovery, and password reset', () async {
    final mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path.contains('/signup')) {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'user_123',
              'user_metadata': {'name': 'Budi Purwokerto'},
            }
          }),
          200,
        );
      } else if (path.contains('/token')) {
        return http.Response(
          jsonEncode({
            'access_token': 'fake_access_token',
            'user': {
              'id': 'user_123',
              'user_metadata': {'name': 'Budi Purwokerto'},
            }
          }),
          200,
        );
      } else if (path.contains('/recover')) {
        return http.Response(jsonEncode({}), 200);
      } else if (path.contains('/verify')) {
        return http.Response(
          jsonEncode({'access_token': 'recovery_token'}),
          200,
        );
      } else if (path.contains('/user')) {
        return http.Response(
          jsonEncode({'id': 'user_123'}),
          200,
        );
      }
      return http.Response('Not Found', 404);
    });

    final authService = AuthService(client: mockClient);

    // Sign up
    final upResult = await authService.signUp(
      email: 'budi@mampir.id',
      password: 'password123',
      name: 'Budi Purwokerto',
    );
    expect(upResult.success, isTrue);
    expect(upResult.userName, equals('Budi Purwokerto'));

    // Sign in
    final inResult = await authService.signIn(
      email: 'budi@mampir.id',
      password: 'password123',
    );
    expect(inResult.success, isTrue);
    expect(inResult.accessToken, equals('fake_access_token'));

    // Send OTP
    final otpResult = await authService.sendPasswordResetOtp('budi@mampir.id');
    expect(otpResult.success, isTrue);

    // Verify OTP & reset password
    final resetResult = await authService.verifyOtpAndResetPassword(
      email: 'budi@mampir.id',
      token: '123456',
      newPassword: 'newpassword123',
    );
    expect(resetResult.success, isTrue);
  });

  testWidgets('Top Header does not overflow on a narrow 320px screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'selected_region': 'Purwokerto Utara',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Purwokerto Utara'), findsOneWidget);
  });

  testWidgets('SearchScreen with showAll=true displays all 25 places and sorts properly without filtering out restaurants', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final places = await ApiService().fetchPlaces();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          allPlaces: places,
          showAll: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 25 places are counted in the header
    expect(find.text('Menampilkan 25 tempat sesuai dengan budget dan preferensimu'), findsOneWidget);

    final listScrollable = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));

    // Verify restaurants are present in the list
    final pringsewuFinder = find.text('Restoran Pringsewu Purwokerto');
    await tester.scrollUntilVisible(pringsewuFinder, 300, scrollable: listScrollable);
    expect(pringsewuFinder, findsOneWidget);

    // Tap 'Rating Tertinggi' sort pill
    final ratingSortFinder = find.text('Rating Tertinggi');
    await tester.ensureVisible(ratingSortFinder);
    await tester.tap(ratingSortFinder);
    await tester.pumpAndSettle();

    // Still 25 places
    expect(find.text('Menampilkan 25 tempat sesuai dengan budget dan preferensimu'), findsOneWidget);
    await tester.scrollUntilVisible(pringsewuFinder, 300, scrollable: listScrollable);
    expect(pringsewuFinder, findsOneWidget);
  });

  testWidgets('BudgetFilterModal keeps all place types by default and does not exclude Restoran', (WidgetTester tester) async {
    BudgetFilterData? appliedData;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                BudgetFilterModal.show(
                  ctx,
                  currentBudget: 50000,
                  currentPlaceTypes: {},
                ).then((res) => appliedData = res);
              },
              child: const Text('Open Filter'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Filter'));
    await tester.pumpAndSettle();

    // Ensure button is scrolled into view before tapping
    final applyFinder = find.text('Terapkan Filter');
    await tester.ensureVisible(applyFinder);
    await tester.tap(applyFinder);
    await tester.pumpAndSettle();

    expect(appliedData, isNotNull);
    // placeTypes should be empty (all types allowed, Restoran not excluded)
    expect(appliedData!.placeTypes, isEmpty);
  });

  testWidgets('RouteScreen displays place name and Mulai Navigasi button', (WidgetTester tester) async {
    final places = await ApiService().fetchPlaces();
    final samplePlace = places.first;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteScreen(
          place: samplePlace,
          userLocation: const LatLng(-7.4244, 109.2302),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mulai Navigasi'), findsOneWidget);
    expect(find.text(samplePlace.name), findsAtLeastNWidgets(1));
  });
}
