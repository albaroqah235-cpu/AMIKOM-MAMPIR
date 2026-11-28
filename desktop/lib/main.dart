import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://oztqhofaadjldjrowrgy.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96dHFob2ZhYWRqbGRqcm93cmd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ5NzM4MzEsImV4cCI6MjExMDU0OTgzMX0.Do3ET862Lik6anMGmazYswh_8hBCX6Iz_80jqWuI4-U',
);

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MAMPIR Admin',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd99b25),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const AdminLoginPage(),
  );
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.text.trim(),
          'password': password.text,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Email atau kata sandi admin tidak valid.');
      }
      final token =
          (jsonDecode(response.body) as Map<String, dynamic>)['access_token']
              as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak tersedia.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminDashboard(token: token)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        width: 420,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 56),
                const SizedBox(height: 12),
                Text(
                  'MAMPIR Admin',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email admin'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => login(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.token});
  final String token;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> places = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> preferences = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();
  String selectedZone = 'Semua Wilayah';

  static const List<String> zones = [
    'Semua Wilayah',
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara (Unsoed)',
    'Sokaraja',
    'Purwokerto Timur & Sumbang',
    'Purwokerto Barat & Selatan',
  ];

  Map<String, String> get headers => {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer ${widget.token}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  static String _getZoneKeyword(String zone) {
    final l = zone.toLowerCase();
    if (l.contains('baturraden')) return 'baturraden';
    if (l.contains('sokaraja')) return 'sokaraja';
    if (l.contains('utara') || l.contains('unsoed')) return 'utara';
    if (l.contains('timur') || l.contains('sumbang')) return 'timur';
    if (l.contains('barat')) return 'barat';
    if (l.contains('selatan')) return 'selatan';
    return 'purwokerto';
  }

  List<Map<String, dynamic>> get filteredPlaces {
    return places.where((place) {
      if (selectedZone != 'Semua Wilayah') {
        final city = (place['city'] as String? ?? '').toLowerCase();
        final addr = (place['address'] as String? ?? '').toLowerCase();
        final kw = _getZoneKeyword(selectedZone);
        if (!city.contains(kw) && !addr.contains(kw)) {
          return false;
        }
      }
      final query = searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = (place['name'] as String? ?? '').toLowerCase();
        final cat = (place['category'] as String? ?? '').toLowerCase();
        final addr = (place['address'] as String? ?? '').toLowerCase();
        if (!name.contains(query) && !cat.contains(query) && !addr.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  double get _averageRating {
    if (places.isEmpty) return 0;
    return places.fold<double>(
          0,
          (sum, place) => sum + ((place['rating'] as num?)?.toDouble() ?? 0),
        ) /
        places.length;
  }

  double get _averageBudget {
    if (places.isEmpty) return 0;
    return places.fold<double>(
          0,
          (sum, place) =>
              sum +
              ((place['avg_price'] as num?)?.toDouble() ??
                  ((place['min_price'] as num?)?.toDouble() ?? 0)),
        ) /
        places.length;
  }

  Future<void> loadPlaces() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/places?select=*&order=name.asc'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil katalog tempat.');
      }
      setState(
        () => places = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/categories?select=*&is_active=eq.true&order=sort_order,name',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/preferences?select=*&is_active=eq.true&order=sort_order,name',
          ),
          headers: headers,
        ),
      ]);
      if (results[0].statusCode == 200) {
        categories = (jsonDecode(results[0].body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      }
      if (results[1].statusCode == 200) {
        preferences = (jsonDecode(results[1].body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      }
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> savePlace(Map<String, dynamic> place) async {
    final editableFields = <String, dynamic>{
      'name': place['name'],
      'address': place['address'],
      'description': place['description'],
      'image_url': place['image_url'],
      'open_hours': place['open_hours'],
      'owner_phone': place['owner_phone'],
      'min_price': place['min_price'],
      'max_price': place['max_price'],
      'avg_price': place['avg_price'],
      'category': place['category'],
      'facilities': place['facilities'],
      'latitude': place['latitude'],
      'longitude': place['longitude'],
      'menu_highlights': place['menu_highlights'],
    };
    final response = await http.patch(
      Uri.parse('$supabaseUrl/rest/v1/places?id=eq.${place['id']}'),
      headers: headers,
      body: jsonEncode({...place, 'override_fields': editableFields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal menyimpan perubahan.');
    }
    final category = categories.where(
      (item) => item['name'] == place['category'],
    );
    if (category.isNotEmpty) {
      final categoryResponse = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/place_categories?on_conflict=place_id'),
        headers: {...headers, 'Prefer': 'resolution=merge-duplicates'},
        body: jsonEncode({
          'place_id': place['id'],
          'category_id': category.first['id'],
        }),
      );
      if (categoryResponse.statusCode < 200 ||
          categoryResponse.statusCode >= 300) {
        throw Exception('Gagal menyimpan kategori tempat.');
      }
    }
    final deletePreferences = await http.delete(
      Uri.parse(
        '$supabaseUrl/rest/v1/place_preferences?place_id=eq.${place['id']}',
      ),
      headers: headers,
    );
    if (deletePreferences.statusCode < 200 ||
        deletePreferences.statusCode >= 300) {
      throw Exception('Gagal memperbarui preferensi tempat.');
    }
    final selectedPreferences = preferences
        .where(
          (item) => (place['facilities'] as List<dynamic>? ?? const [])
              .contains(item['name']),
        )
        .map((item) => {'place_id': place['id'], 'preference_id': item['id']})
        .toList();
    if (selectedPreferences.isNotEmpty) {
      final preferenceResponse = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/place_preferences'),
        headers: headers,
        body: jsonEncode(selectedPreferences),
      );
      if (preferenceResponse.statusCode < 200 ||
          preferenceResponse.statusCode >= 300) {
        throw Exception('Gagal menyimpan preferensi tempat.');
      }
    }
    await loadPlaces();
  }

  Future<void> syncGoogle() async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/sync-places'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Sinkronisasi gagal (${response.statusCode}). Pastikan Edge Function sync-places sudah aktif.',
      );
    }

    await loadPlaces();
  }

  Future<void> manageLookupValues({
    required String table,
    required String title,
    required List<Map<String, dynamic>> values,
  }) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Kelola $title'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values
                    .map(
                      (value) => InputChip(
                        label: Text('${value['name']}'),
                        onDeleted: () async {
                          await http.patch(
                            Uri.parse(
                              '$supabaseUrl/rest/v1/$table?id=eq.${value['id']}',
                            ),
                            headers: headers,
                            body: jsonEncode({'is_active': false}),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await loadPlaces();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Tambah $title',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      await http.post(
                        Uri.parse('$supabaseUrl/rest/v1/$table'),
                        headers: headers,
                        body: jsonEncode({'name': name}),
                      );
                      controller.clear();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      await loadPlaces();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> addPlace(Map<String, dynamic> place) async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/places'),
      headers: headers,
      body: jsonEncode(place),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal menambahkan tempat (${response.statusCode}): ${response.body}');
    }
    await loadPlaces();
  }

  Future<void> deletePlace(Map<String, dynamic> place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus Tempat'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${place['name']}" dari katalog? '
          'Tindakan ini akan menghapus data dari sistem database Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$supabaseUrl/rest/v1/places?id=eq.${place['id']}'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gagal menghapus tempat (${response.statusCode}).');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tempat "${place['name']}" berhasil dihapus.')),
        );
      }
      await loadPlaces();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> showStats() async {
    final response = await http.get(
      Uri.parse(
        '$supabaseUrl/rest/v1/analytics_events?select=event_name,created_at&limit=1000',
      ),
      headers: headers,
    );
    if (!mounted) return;
    final eventCount = response.statusCode == 200
        ? (jsonDecode(response.body) as List<dynamic>).length
        : 0;

    final avgRating = _averageRating;
    final avgBudget = _averageBudget;

    // Hitung sebaran tempat per 7 zona wilayah Purwokerto
    final zoneCounts = <String, int>{};
    for (final z in zones.where((z) => z != 'Semua Wilayah')) {
      final kw = _getZoneKeyword(z);
      final count = places.where((p) {
        final c = (p['city'] as String? ?? '').toLowerCase();
        final a = (p['address'] as String? ?? '').toLowerCase();
        return c.contains(kw) || a.contains(kw);
      }).length;
      zoneCounts[z] = count;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics_rounded, color: Color(0xffd99b25)),
            SizedBox(width: 10),
            Text('Statistik Kuliner Purwokerto (WADM-1)'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total Tempat', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${places.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Rating Rata-rata', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${avgRating.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Rata-rata Budget', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('Rp ${avgBudget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xffd99b25))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Distribusi Sebaran Tempat per 7 Zona Wilayah:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...zoneCounts.entries.map((e) {
                  final pct = places.isNotEmpty ? (e.value / places.length * 100).toStringAsFixed(1) : '0';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                        Text('${e.value} tempat ($pct%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Text(
                  'Event analitik tercatat: $eventCount interaksi',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MAMPIR Admin Dashboard'),
      actions: [
        FilledButton.tonalIcon(
          onPressed: () async {
            try {
              await syncGoogle();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text('Sinkron Google'),
        ),
        IconButton(
          onPressed: () => manageLookupValues(
            table: 'categories',
            title: 'kategori',
            values: categories,
          ),
          icon: const Icon(Icons.category_outlined),
          tooltip: 'Kelola kategori',
        ),
        IconButton(
          onPressed: () => manageLookupValues(
            table: 'preferences',
            title: 'preferensi/fasilitas',
            values: preferences,
          ),
          icon: const Icon(Icons.tune),
          tooltip: 'Kelola preferensi',
        ),
        IconButton(
          onPressed: showStats,
          icon: const Icon(Icons.analytics_outlined),
          tooltip: 'Statistik',
        ),
        IconButton(
          onPressed: loadPlaces,
          icon: const Icon(Icons.refresh),
          tooltip: 'Muat ulang',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Center(child: Text('Data tersinkron Supabase')),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Katalog tempat (${filteredPlaces.length} dari ${places.length})',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final newPlace = await showAddPlaceDialog(
                          context,
                          token: widget.token,
                          categories: categories,
                          preferences: preferences,
                        );
                        if (newPlace != null) {
                          try {
                            await addPlace(newPlace);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tempat baru berhasil ditambahkan ke Supabase!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Tempat Baru (WADM-3)'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari tempat berdasarkan nama, kategori, atau alamat (WADM-2)...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => searchController.clear()),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedZone,
                        decoration: InputDecoration(
                          labelText: 'Filter 7 Zona Wilayah (WADM-2)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: zones
                            .map((z) => DropdownMenuItem(value: z, child: Text(z, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) => setState(() => selectedZone = val ?? 'Semua Wilayah'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: filteredPlaces.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Tidak ada tempat kuliner yang sesuai dengan pencarian atau filter zona.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredPlaces.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final place = filteredPlaces[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    place['category'] == 'Warkop'
                                        ? Icons.coffee_rounded
                                        : place['category'] == 'Restoran'
                                            ? Icons.restaurant_rounded
                                            : Icons.local_cafe_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      '${place['name'] ?? '-'}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${place['category'] ?? 'Cafe'} • ${place['city'] ?? 'Purwokerto'}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${place['address'] ?? '-'}\nBudget: Rp ${place['min_price'] ?? 0} - Rp ${place['max_price'] ?? 0} • Rating: ${place['rating'] ?? '-'} ★',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final updatedMenu =
                                            await showMenuEditor(
                                              context,
                                              place,
                                            );
                                        if (updatedMenu == null) return;
                                        try {
                                          await savePlace({
                                            ...place,
                                            'menu_highlights': updatedMenu,
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Menu berhasil diperbarui & disinkronkan!',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.restaurant_menu_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Menu'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () async {
                                        final edited = await showPlaceEditor(
                                          context,
                                          place,
                                          token: widget.token,
                                          categories: categories,
                                          preferences: preferences,
                                        );
                                        if (edited == null) return;
                                        try {
                                          await savePlace(edited);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(SnackBar(content: Text('$e')));
                                          }
                                        }
                                      },
                                      child: const Text('Edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: 'Hapus Tempat (WADM-5)',
                                      onPressed: () => deletePlace(place),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    ),
  );
}

Future<String?> pickAndUploadPlaceImage(String token) async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;

  final file = input.files!.first;
  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();
  reader.onLoadEnd.listen((_) {
    if (reader.result is ByteBuffer) {
      completer.complete((reader.result as ByteBuffer).asUint8List());
    } else if (reader.result is Uint8List) {
      completer.complete(reader.result as Uint8List);
    } else {
      completer.complete(null);
    }
  });
  reader.onError.listen((_) => completer.complete(null));
  reader.readAsArrayBuffer(file);

  final bytes = await completer.future;
  if (bytes == null) throw Exception('Gagal membaca file gambar.');

  final ext = file.name.contains('.')
      ? file.name.split('.').last.toLowerCase()
      : 'jpg';
  final fileName = 'cafe_${DateTime.now().millisecondsSinceEpoch}.$ext';
  final contentType = file.type.isNotEmpty ? file.type : 'image/jpeg';

  final uploadUrl = Uri.parse(
    '$supabaseUrl/storage/v1/object/place-images/$fileName',
  );
  final response = await http.post(
    uploadUrl,
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': contentType,
      'x-upsert': 'true',
    },
    body: bytes,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Upload gagal (${response.statusCode}): ${response.body}');
  }

  return '$supabaseUrl/storage/v1/object/public/place-images/$fileName';
}

Widget buildPhotoUploadField({
  required BuildContext context,
  required TextEditingController imageController,
  required String token,
}) {
  bool uploading = false;
  return StatefulBuilder(
    builder: (ctx, setPhotoState) {
      final url = imageController.text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        width: 72,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 54,
                          color: Colors.black26,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 54,
                        color: Colors.black26,
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setPhotoState(() => uploading = true);
                              try {
                                final uploadedUrl =
                                    await pickAndUploadPlaceImage(token);
                                if (uploadedUrl != null) {
                                  setPhotoState(() {
                                    imageController.text = uploadedUrl;
                                  });
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setPhotoState(() => uploading = false);
                                }
                              }
                            },
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(
                        uploading ? 'Mengupload...' : 'Upload Foto dari PC',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      url.isNotEmpty ? 'Foto terpasang' : 'Belum ada foto',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextField(
            controller: imageController,
            decoration: const InputDecoration(
              labelText: 'URL Foto (otomatis terisi saat upload)',
            ),
            onChanged: (_) => setPhotoState(() {}),
          ),
          const SizedBox(height: 6),
        ],
      );
    },
  );
}

Future<List<Map<String, dynamic>>?> showMenuEditor(
  BuildContext context,
  Map<String, dynamic> place,
) {
  final rawList = (place['menu_highlights'] as List<dynamic>?) ?? const [];
  final items = rawList.map((e) {
    final m = e is Map<String, dynamic>
        ? e
        : <String, dynamic>{'name': '$e', 'price': 0};
    return {
      'name': TextEditingController(text: '${m['name'] ?? ''}'),
      'price': TextEditingController(text: '${m['price'] ?? 0}'),
    };
  }).toList();

  return showDialog<List<Map<String, dynamic>>>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu_rounded, color: Color(0xffd99b25)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Edit Menu — ${place['name'] ?? ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada menu andalan. Klik "+ Tambah Menu" di bawah.',
                    ),
                  ),
                ...List.generate(items.length, (i) {
                  final row = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: row['name'],
                            decoration: InputDecoration(
                              labelText: 'Nama Menu ${i + 1}',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row['price'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga (Rp)',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Hapus Menu',
                          onPressed: () =>
                              setModalState(() => items.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setModalState(() {
                      items.add({
                        'name': TextEditingController(),
                        'price': TextEditingController(text: '20000'),
                      });
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Menu'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final result = items
                  .map(
                    (row) => <String, dynamic>{
                      'name': row['name']!.text.trim(),
                      'price': int.tryParse(row['price']!.text.trim()) ?? 0,
                    },
                  )
                  .where((m) => (m['name'] as String).isNotEmpty)
                  .toList();
              Navigator.pop(dialogCtx, result);
            },
            child: const Text('Simpan Menu'),
          ),
        ],
      ),
    ),
  );
}

Future<Map<String, dynamic>?> showPlaceEditor(
  BuildContext context,
  Map<String, dynamic> source, {
  required String token,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> preferences,
}) {
  final name = TextEditingController(text: '${source['name'] ?? ''}');
  final description = TextEditingController(
    text: '${source['description'] ?? ''}',
  );
  final address = TextEditingController(text: '${source['address'] ?? ''}');
  final image = TextEditingController(text: '${source['image_url'] ?? ''}');
  final openHours = TextEditingController(
    text: '${source['open_hours'] ?? ''}',
  );
  final ownerPhone = TextEditingController(
    text: '${source['owner_phone'] ?? ''}',
  );
  final minPrice = TextEditingController(text: '${source['min_price'] ?? 0}');
  final maxPrice = TextEditingController(text: '${source['max_price'] ?? 0}');
  final latitude = TextEditingController(text: '${source['latitude'] ?? ''}');
  final longitude = TextEditingController(text: '${source['longitude'] ?? ''}');
  final facilities = TextEditingController(
    text: ((source['facilities'] as List<dynamic>?) ?? const []).join(', '),
  );
  var selectedCategory =
      '${source['category'] ?? categories.firstOrNull?['name'] ?? ''}';
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Edit tempat'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              buildPhotoUploadField(
                context: context,
                imageController: image,
                token: token,
              ),
              TextField(
                controller: openHours,
                decoration: const InputDecoration(labelText: 'Jam buka'),
              ),
              TextField(
                controller: ownerPhone,
                decoration: const InputDecoration(
                  labelText: 'No. WhatsApp Pemilik',
                  hintText: 'Contoh: 081234567890',
                ),
                keyboardType: TextInputType.phone,
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    categories.any((item) => item['name'] == selectedCategory)
                    ? selectedCategory
                    : null,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: categories
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: '${item['name']}',
                        child: Text('${item['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    selectedCategory = value ?? selectedCategory,
              ),
              TextField(
                controller: facilities,
                decoration: const InputDecoration(
                  labelText: 'Preferensi/fasilitas (pisahkan koma)',
                  hintText: 'WiFi, Colokan, AC, Parkir',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latitude,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: longitude,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPrice,
                      decoration: const InputDecoration(
                        labelText: 'Budget minimum',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxPrice,
                      decoration: const InputDecoration(
                        labelText: 'Budget maksimum',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            ...source,
            'name': name.text.trim(),
            'address': address.text.trim(),
            'description': description.text.trim(),
            'image_url': image.text.trim(),
            'open_hours': openHours.text.trim(),
            'owner_phone': ownerPhone.text.trim(),
            'category': selectedCategory,
            'facilities': facilities.text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(),
            'latitude': double.tryParse(latitude.text) ?? source['latitude'],
            'longitude': double.tryParse(longitude.text) ?? source['longitude'],
            'min_price': int.tryParse(minPrice.text) ?? source['min_price'],
            'max_price': int.tryParse(maxPrice.text) ?? source['max_price'],
            'avg_price': ((int.tryParse(minPrice.text) ?? (source['min_price'] ?? 0)) +
                    (int.tryParse(maxPrice.text) ?? (source['max_price'] ?? 0))) ~/ 2,
          }),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<Map<String, dynamic>?> showAddPlaceDialog(
  BuildContext context, {
  required String token,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> preferences,
}) {
  final name = TextEditingController();
  final address = TextEditingController();
  final description = TextEditingController();
  final image = TextEditingController(text: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80');
  final openHours = TextEditingController(text: '09.00 - 22.00 WIB');
  final ownerPhone = TextEditingController();
  final minPrice = TextEditingController(text: '15000');
  final maxPrice = TextEditingController(text: '40000');
  final latitude = TextEditingController(text: '-7.4244');
  final longitude = TextEditingController(text: '109.2302');
  final facilities = TextEditingController(text: 'WiFi, Colokan, Parkir');

  var selectedCategory = categories.firstOrNull?['name']?.toString() ?? 'Cafe';
  var selectedCity = 'Purwokerto Kota';

  final availableZones = [
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara (Unsoed)',
    'Sokaraja',
    'Purwokerto Timur & Sumbang',
    'Purwokerto Barat & Selatan',
  ];

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_location_alt_rounded, color: Color(0xffd99b25)),
            SizedBox(width: 10),
            Text('Tambah Tempat Baru (WADM-3)'),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tempat *',
                    hintText: 'Contoh: Kopi Roemah Baturraden',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Kategori *'),
                        items: (categories.isNotEmpty ? categories : [{'name': 'Cafe'}, {'name': 'Warkop'}, {'name': 'Restoran'}])
                            .map((item) => DropdownMenuItem<String>(
                                  value: '${item['name']}',
                                  child: Text('${item['name']}'),
                                ))
                            .toList(),
                        onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCity,
                        decoration: const InputDecoration(labelText: 'Zona Wilayah *'),
                        items: availableZones
                            .map((z) => DropdownMenuItem(value: z, child: Text(z, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) => setModalState(() => selectedCity = val ?? selectedCity),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap *',
                    hintText: 'Jl. Raya Purwokerto No. 12',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latitude,
                        decoration: const InputDecoration(
                          labelText: 'Latitude (-7.6 s/d -7.2) *',
                          hintText: '-7.4244',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: longitude,
                        decoration: const InputDecoration(
                          labelText: 'Longitude (109.0 s/d 109.5) *',
                          hintText: '109.2302',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPrice,
                        decoration: const InputDecoration(labelText: 'Harga Min (Rp)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxPrice,
                        decoration: const InputDecoration(labelText: 'Harga Max (Rp)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openHours,
                  decoration: const InputDecoration(labelText: 'Jam Operasional'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ownerPhone,
                  decoration: const InputDecoration(
                    labelText: 'No. WhatsApp Pemilik',
                    hintText: 'Contoh: 081234567890',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                buildPhotoUploadField(
                  context: ctx,
                  imageController: image,
                  token: token,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deskripsi Singkat'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facilities,
                  decoration: const InputDecoration(
                    labelText: 'Fasilitas (pisahkan dengan koma)',
                    hintText: 'WiFi, Colokan, AC, Parkir',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              final addr = address.text.trim();
              final lat = double.tryParse(latitude.text.trim());
              final lng = double.tryParse(longitude.text.trim());
              final min = int.tryParse(minPrice.text.trim()) ?? 0;
              final max = int.tryParse(maxPrice.text.trim()) ?? 0;

              if (n.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama tempat wajib diisi.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              if (addr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alamat tempat wajib diisi.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              if (lat == null || lat < -7.6 || lat > -7.2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Latitude tidak valid untuk wilayah Purwokerto/Banyumas (-7.6 s/d -7.2).'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              if (lng == null || lng < 109.0 || lng > 109.5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Longitude tidak valid untuk wilayah Purwokerto/Banyumas (109.0 s/d 109.5).'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final facList = facilities.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final newId = 'pwt-${DateTime.now().millisecondsSinceEpoch}';
              final newPlace = {
                'id': newId,
                'name': n,
                'city': selectedCity,
                'category': selectedCategory,
                'address': addr,
                'description': description.text.trim(),
                'open_hours': openHours.text.trim(),
            'owner_phone': ownerPhone.text.trim(),
                'image_url': image.text.trim(),
                'latitude': lat,
                'longitude': lng,
                'min_price': min,
                'max_price': max,
                'avg_price': (min + max) ~/ 2,
                'rating': 4.5,
                'review_count': 10,
                'facilities': facList,
                'menu_highlights': <Map<String, dynamic>>[],
                'data_source': 'admin',
              };

              Navigator.pop(dialogCtx, newPlace);
            },
            child: const Text('Simpan Tempat'),
          ),
        ],
      ),
    ),
  );
}
