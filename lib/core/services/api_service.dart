import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../data/models/destination_model.dart';
import 'supabase_service.dart';

/// Service untuk menangani query eksternal online (Supabase, OSRM Route, OpenStreetMap Nominatim).
/// Menggantikan backend Laravel perantara dengan koneksi langsung ke Supabase Cloud.
class ApiService {
  /// Mengambil daftar destinasi terverifikasi langsung dari Supabase Cloud
  static Future<List<DestinationModel>?> fetchVerifiedDestinations() async {
    try {
      final supabaseList = await SupabaseService().fetchDestinations();
      if (supabaseList != null && supabaseList.isNotEmpty) {
        return supabaseList;
      }
    } catch (e) {
      debugPrint('ApiService.fetchVerifiedDestinations via Supabase error: $e');
    }
    return null;
  }

  /// Pencarian destinasi online via Supabase atau OpenStreetMap Nominatim
  static Future<List<DestinationModel>> searchOsmDestinations(String query) async {
    // 1. Coba cari di database Supabase terlebih dahulu
    try {
      final supabaseResults = await SupabaseService().searchDestinations(query);
      if (supabaseResults.isNotEmpty) {
        return supabaseResults;
      }
    } catch (_) {}

    // 2. Fallback pencarian langsung ke OpenStreetMap Nominatim publik
    return _searchDirectNominatim(query);
  }

  /// Direct Nominatim search ke OpenStreetMap publik
  static Future<List<DestinationModel>> _searchDirectNominatim(String query) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(queryParameters: {
        'q': '$query Yogyakarta Merapi',
        'format': 'json',
        'limit': '6',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MeraTrip-Flutter-App/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? -7.5833;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 110.4500;
          final name = item['display_name']?.toString().split(',').first ?? query;

          return DestinationModel(
            id: 8000 + idx,
            name: name,
            description: item['display_name'] ?? 'Destinasi lereng Merapi via OpenStreetMap',
            categoryId: 1,
            categoryName: 'Wisata Alam',
            latitude: lat,
            longitude: lon,
            elevationMdpl: 850,
            ticketPrice: 10000.0,
            ticketPriceLabel: 'Tiket Masuk',
            openingHours: '06.00 - 17.00 WIB',
            estimatedDuration: '45 Menit',
            temperatureRange: '18°C - 24°C',
            address: item['display_name'] ?? 'Kawasan Merapi, D.I. Yogyakarta',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg',
            isSavedOffline: false,
            rating: 4.7,
            reviewCount: 150,
            facilities: const ['Parkir', 'Spot Foto'],
            distanceKm: 3.5,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Direct Nominatim fallback error: $e');
    }
    return [];
  }

  /// Menghitung rute navigasi jalan via public Open Source Routing Machine (OSRM)
  static Future<Map<String, dynamic>?> getOsrmRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final List<LatLng> points = coordinates.map((coord) {
            final c = coord as List;
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();

          return {
            'coordinates': points,
            'points': points,
            'distance_km': (distanceMeters / 1000.0),
            'duration_minutes': (durationSeconds / 60.0).round(),
          };
        }
      }
    } catch (e) {
      debugPrint('OSRM routing direct error: $e');
    }
    return null;
  }

  /// AI Assistant backend fallback (jika diperlukan)
  static Future<Map<String, dynamic>?> chatWithGemini({required String message}) async {
    return null; // Menggunakan GeminiService cloud-native langsung
  }
}
