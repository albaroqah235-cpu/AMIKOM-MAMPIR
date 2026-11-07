import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mampir_app/config/api_config.dart';
import 'package:mampir_app/main.dart';
import 'package:mampir_app/screens/home_screen.dart';
import 'package:mampir_app/screens/notification_screen.dart';
import 'package:mampir_app/screens/place_detail_screen.dart';
import 'package:mampir_app/screens/route_screen.dart';
import 'package:mampir_app/screens/search_screen.dart';
import 'package:mampir_app/screens/settings_screen.dart';
import 'package:mampir_app/services/api_service.dart';
import 'package:mampir_app/services/auth_service.dart';
import 'package:mampir_app/services/google_places_service.dart';
import 'package:mampir_app/services/google_routes_service.dart';
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

  test(
    'ApiService returns 25 authentic places for Purwokerto & Sekitarnya',
    () async {
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
    },
  );

  test(
    'All places strictly belong to categories Cafe, Warkop, or Restoran',
    () async {
      final apiService = ApiService();
      final places = await apiService.fetchPlaces();

      const allowedCategories = {'Cafe', 'Warkop', 'Restoran'};
      for (final p in places) {
        expect(
          allowedCategories.contains(p.category),
          isTrue,
          reason: 'Place ${p.name} has unexpected category: ${p.category}',
        );
      }

      final categories = places.map((p) => p.category).toSet();
      expect(categories, equals(allowedCategories));
    },
  );

  test(
    'RecommendationService filters Purwokerto sub-regions accurately',
    () async {
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
    },
  );

  test(
    'PreferenceService getSearchHistory returns empty list when raw is null',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefService = PreferenceService();

      final history = await prefService.getSearchHistory();
      expect(history, isEmpty);

      // After adding a search keyword, it should be recorded
      await prefService.addSearchKeyword('Kopi Keprok');
      final updated = await prefService.getSearchHistory();
      expect(updated, equals(['Kopi Keprok']));
    },
  );

  testWidgets(
    'SettingsScreen has direct notification toggle and no rating/share',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'setting_notification_enabled': true,
        'user_name': 'Penjelajah Test',
      });

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(isRootTab: true)),
      );
      await tester.pumpAndSettle();

      // Verify Direct Switch toggle for Notifikasi exists
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Verify title is 'Profil Pengguna' and not 'Pengaturan & Akun'
      expect(find.text('Profil Pengguna'), findsOneWidget);
      expect(find.text('Pengaturan & Akun'), findsNothing);

      // Verify 'Beri Rating MAMPIR', 'Bagikan Aplikasi', 'Bahasa', and 'Bantuan & Hubungi Kami' are NOT present
      expect(find.text('Beri Rating MAMPIR'), findsNothing);
      expect(find.text('Bagikan Aplikasi'), findsNothing);
      expect(find.text('Bahasa'), findsNothing);
      expect(find.text('Bantuan & Hubungi Kami'), findsNothing);
    },
  );

  testWidgets(
    'NotificationScreen displays clean empty state when there are no notifications',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Notifikasi'), findsOneWidget);
      expect(find.text('Tempat favorit kamu sedang promo!'), findsNothing);
    },
  );

  test(
    'AuthService performs signUp, signIn, OTP recovery, and password reset',
    () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/signup')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user_123',
                'user_metadata': {'name': 'Budi Purwokerto'},
              },
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
              },
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
          return http.Response(jsonEncode({'id': 'user_123'}), 200);
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
      final otpResult = await authService.sendPasswordResetOtp(
        'budi@mampir.id',
      );
      expect(otpResult.success, isTrue);

      // Verify OTP & reset password
      final resetResult = await authService.verifyOtpAndResetPassword(
        email: 'budi@mampir.id',
        token: '123456',
        newPassword: 'newpassword123',
      );
      expect(resetResult.success, isTrue);
    },
  );

  testWidgets('Top Header does not overflow on a narrow 320px screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'selected_region': 'Purwokerto Utara',
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Purwokerto Utara'), findsOneWidget);
  });

  testWidgets(
    'SearchScreen with showAll=true displays all 25 places and sorts properly without filtering out restaurants',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final places = await ApiService().fetchPlaces();

      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(allPlaces: places, showAll: true)),
      );
      await tester.pumpAndSettle();

      // Verify all 25 places are counted in the header
      expect(
        find.text(
          'Menampilkan 25 tempat sesuai dengan budget dan preferensimu',
        ),
        findsOneWidget,
      );

      final listScrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );

      // Verify restaurants are present in the list
      final restaurantFinder = find.text('Soto H. Loso Sokaraja');
      await tester.scrollUntilVisible(
        restaurantFinder,
        300,
        scrollable: listScrollable,
      );
      expect(restaurantFinder, findsOneWidget);

      // Tap 'Rating Tertinggi' sort pill
      final ratingSortFinder = find.text('Rating Tertinggi');
      await tester.ensureVisible(ratingSortFinder);
      await tester.tap(ratingSortFinder);
      await tester.pumpAndSettle();

      // Still 25 places
      expect(
        find.text(
          'Menampilkan 25 tempat sesuai dengan budget dan preferensimu',
        ),
        findsOneWidget,
      );
      expect(find.text('Rating Tertinggi'), findsOneWidget);
    },
  );

  testWidgets(
    'BudgetFilterModal keeps all place types by default and does not exclude Restoran',
    (WidgetTester tester) async {
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
    },
  );

  testWidgets('RouteScreen displays place name and Mulai Navigasi button', (
    WidgetTester tester,
  ) async {
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

  test(
    'GooglePlacesService searches and maps authentic places with pricing and category',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'gplace_surabaya_123',
                'displayName': {'text': 'Ayam Penyet Surabaya Sawangan'},
                'formattedAddress':
                    'Jl. Pahlawan No.35, Kec. Purwokerto Bar., Kabupaten Banyumas',
                'location': {'latitude': -7.4312, 'longitude': 109.2245},
                'rating': 4.4,
                'userRatingCount': 2465,
                'priceLevel': 'PRICE_LEVEL_MODERATE',
                'primaryType': 'indonesian_restaurant',
              },
            ],
          }),
          200,
        );
      });

      final service = GooglePlacesService(client: mockClient);
      final results = await service.searchPlaces('ayam penyet');

      expect(results.length, equals(1));
      final place = results.first;
      expect(place.name, equals('Ayam Penyet Surabaya Sawangan'));
      expect(place.city, equals('Purwokerto Barat'));
      expect(place.rating, equals(4.4));
      expect(place.reviewCount, equals(2465));
      expect(place.minPrice, equals(25000));
      expect(place.maxPrice, equals(60000));
    },
  );

  test(
    'GoogleRoutesService decodes polyline and formats duration and distance',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distanceMeters': 1333,
                'duration': '199s',
                'polyline': {
                  'encodedPolyline':
                      'nail@{buyStC@iC`TKnADXdHz@hDf@jJhAtAPx@PbA\\jBhAfAt@hC~A',
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GoogleRoutesService(client: mockClient);
      final result = await service.computeRoute(
        origin: const LatLng(-7.4244, 109.2304),
        destination: const LatLng(-7.4312, 109.2245),
      );

      expect(result, isNotNull);
      expect(result!.points.isNotEmpty, isTrue);
      expect(result.distanceMeters, equals(1333));
      expect(result.formattedDistance, equals('1.3 km'));
      expect(result.durationSeconds, equals(199));
      expect(result.formattedDuration, equals('4 mnt'));
    },
  );

  testWidgets(
    'SearchScreen receives initialBudget from HomeScreen and displays it',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final places = await ApiService().fetchPlaces();

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            allPlaces: places,
            initialBudget: 75000,
            showAll: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rp 75K'), findsOneWidget);
    },
  );

  test('GooglePlacesService searches and maps authentic places with pricing and category', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'places': [
            {
              'id': 'gplace_surabaya_123',
              'displayName': {'text': 'Ayam Penyet Surabaya Sawangan'},
              'formattedAddress':
                  'Jl. Pahlawan No.35, Kec. Purwokerto Bar., Kabupaten Banyumas',
              'location': {'latitude': -7.4312, 'longitude': 109.2245},
              'rating': 4.4,
              'userRatingCount': 2465,
              'priceLevel': 'PRICE_LEVEL_MODERATE',
              'primaryType': 'indonesian_restaurant',
            }
          ]
        }),
        200,
      );
    });

    final service = GooglePlacesService(client: mockClient);
    final results = await service.searchPlaces('ayam penyet');

    expect(results.length, equals(1));
    final place = results.first;
    expect(place.name, equals('Ayam Penyet Surabaya Sawangan'));
    expect(place.city, equals('Purwokerto Barat'));
    expect(place.rating, equals(4.4));
    expect(place.reviewCount, equals(2465));
    expect(place.minPrice, equals(25000));
    expect(place.maxPrice, equals(60000));
  });

  test('GoogleRoutesService decodes polyline and formats duration and distance', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'routes': [
            {
              'distanceMeters': 1333,
              'duration': '199s',
              'polyline': {
                'encodedPolyline':
                    'nail@{buyStC@iC`TKnADXdHz@hDf@jJhAtAPx@PbA\\jBhAfAt@hC~A',
              }
            }
          ]
        }),
        200,
      );
    });

    final service = GoogleRoutesService(client: mockClient);
    final result = await service.computeRoute(
      origin: const LatLng(-7.4244, 109.2304),
      destination: const LatLng(-7.4312, 109.2245),
    );

    expect(result, isNotNull);
    expect(result!.points.isNotEmpty, isTrue);
    expect(result.distanceMeters, equals(1333));
    expect(result.formattedDistance, equals('1.3 km'));
    expect(result.durationSeconds, equals(199));
    expect(result.formattedDuration, equals('4 mnt'));
  });

  testWidgets('SearchScreen receives initialBudget from HomeScreen and displays it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final places = await ApiService().fetchPlaces();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          allPlaces: places,
          initialBudget: 75000,
          showAll: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rp 75K'), findsOneWidget);
  });

  test('AuthService.translateAuthError translates backend errors to Indonesian', () {
    expect(
      AuthService.translateAuthError('Invalid login credentials'),
      contains('Email atau kata sandi salah'),
    );
    expect(
      AuthService.translateAuthError('invalid_grant: Invalid login credentials'),
      contains('Email atau kata sandi salah'),
    );
    expect(
      AuthService.translateAuthError('Email not confirmed'),
      contains('Email kamu belum dikonfirmasi'),
    );
    expect(
      AuthService.translateAuthError('User already registered'),
      contains('Email ini sudah terdaftar'),
    );
    expect(
      AuthService.translateAuthError('Password should be at least 6 characters'),
      contains('Kata sandi harus terdiri dari minimal 6 karakter'),
    );
    expect(
      AuthService.translateAuthError('over email rate limit'),
      contains('Terlalu banyak permintaan'),
    );
  });

  test('PreferenceService isolates search history between different accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final pref = PreferenceService();

    // 1. Account A logs in and performs searches
    await pref.login(name: 'Asep', email: 'asep@mampir.id', isGuest: false);
    await pref.addSearchKeyword('Kopi Kenangan');
    await pref.addSearchKeyword('Soto Sokaraja');

    final historyA = await pref.getSearchHistory();
    expect(historyA, equals(['Soto Sokaraja', 'Kopi Kenangan']));

    // 2. Account A logs out
    await pref.logout();

    // 3. Guest performs searches
    final guestHistory = await pref.getSearchHistory();
    expect(guestHistory, isEmpty); // Guest should not see Account A's history
    await pref.addSearchKeyword('Bakso');
    expect(await pref.getSearchHistory(), equals(['Bakso']));

    // 4. Account B logs in
    await pref.login(name: 'Budi', email: 'budi@mampir.id', isGuest: false);
    final historyB = await pref.getSearchHistory();
    expect(historyB, isEmpty); // Account B should NOT see Account A or guest history!

    await pref.addSearchKeyword('Warmindo');
    expect(await pref.getSearchHistory(), equals(['Warmindo']));

    // 5. Account A logs back in
    await pref.logout();
    await pref.login(name: 'Asep', email: 'asep@mampir.id', isGuest: false);
    final restoredHistoryA = await pref.getSearchHistory();
    expect(restoredHistoryA, equals(['Soto Sokaraja', 'Kopi Kenangan']));
  });

  test('ApiService all 25 places have audited Google Places coordinates', () async {
    final apiService = ApiService();
    final places = await apiService.fetchPlaces();
    expect(places.length, equals(25));

    // Verify Kopi Kenangan is at real Sudirman location, NOT center of Alun-alun (-7.4244, 109.2302)
    final kopiKenangan = places.firstWhere((p) => p.id == 'pwt-1');
    expect(kopiKenangan.latitude, closeTo(-7.428014, 0.001));
    expect(kopiKenangan.longitude, closeTo(109.242803, 0.001));
    expect(kopiKenangan.address, contains('606'));

    // Verify none of the 25 places are at the old wrong coordinate
    for (final p in places) {
      final isOldAlunAlunCoord = (p.latitude == -7.4244 && p.longitude == 109.2302);
      expect(isOldAlunAlunCoord, isFalse, reason: 'Place ${p.name} still uses old inaccurate coordinate!');
    }
  });

  testWidgets('Bottom navigation has 4 tabs and top-right header has Profile icon', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify 4 tabs are present in bottom navigation
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Cari'), findsOneWidget);
    expect(find.text('Favorit'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);

    // Verify 5th tab 'Akun' is completely removed from bottom navigation
    expect(find.text('Akun'), findsNothing);

    // Verify top-right header has Profile icon with tooltip 'Profil Pengguna'
    expect(find.byTooltip('Profil Pengguna'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Verify Settings icon is NOT in header
    expect(find.byTooltip('Akun & Pengaturan'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('PlaceDetailScreen uses Love icon for favorite, no share or duplicate buttons', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final place = (await ApiService().fetchPlaces()).first;

    await tester.pumpWidget(MaterialApp(home: PlaceDetailScreen(place: place)));
    await tester.pumpAndSettle();

    // Verify back button is present
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Verify share button and old top favorite button are removed from top bar
    expect(find.byIcon(Icons.share_outlined), findsNothing);

    // Verify favorite icon beside title is heart/favorite icon, not bookmark
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    // Tap favorite button to toggle to active
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // Verify it turns into solid favorite icon
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Verify bottom bar does NOT have 'Hapus dari Favorit' button
    expect(find.text('Hapus dari Favorit'), findsNothing);
    // Verify 'Lihat Rute' is still present
    expect(find.text('Lihat Rute'), findsOneWidget);
  });

  test('Google OAuth URL generation & Android deep link callback configuration', () {
    expect(ApiConfig.androidAuthCallback, equals('mampir://auth-callback'));

    final androidUrl = AuthService.getGoogleOAuthUrl(
      redirectUrl: ApiConfig.androidAuthCallback,
    );
    expect(androidUrl, contains('/auth/v1/authorize?provider=google'));
    expect(androidUrl, contains('redirect_to=mampir%3A%2F%2Fauth-callback'));

    final webUrl = AuthService.getGoogleOAuthUrl(
      redirectUrl: 'https://mampir.id',
    );
    expect(webUrl, contains('redirect_to=https%3A%2F%2Fmampir.id'));
  });
}
