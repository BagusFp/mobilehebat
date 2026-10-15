import 'dart:math';

class GeoHelper {
  // Koordinat Puncak Gunung Merapi (2.930 mdpl)
  static const double merapiSummitLat = -7.5407;
  static const double merapiSummitLng = 110.4461;

  // Koordinat Simulasi Pengguna (Pos Retribusi Kaliurang)
  static const double userDefaultLat = -7.5950;
  static const double userDefaultLng = 110.4280;

  /// Menghitung jarak lurus (Great Circle Distance) menggunakan rumus Haversine dalam Kilometer
  static double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLng = _degreesToRadians(endLng - startLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Menghitung jarak dari koordinat pengguna saat ini ke destinasi
  static double distanceToUser(double destLat, double destLng, {double? userLat, double? userLng}) {
    return calculateDistanceKm(
      startLat: userLat ?? userDefaultLat,
      startLng: userLng ?? userDefaultLng,
      endLat: destLat,
      endLng: destLng,
    );
  }

  /// Menghitung jarak dari kawah/puncak Gunung Merapi
  static double distanceFromMerapiSummit(double lat, double lng) {
    return calculateDistanceKm(
      startLat: merapiSummitLat,
      startLng: merapiSummitLng,
      endLat: lat,
      endLng: lng,
    );
  }

  /// Format teks jarak & estimasi waktu berkendara santai lereng (rata-rata kecepatan 25-30 km/jam)
  static String formatDistanceAndDuration(double distanceKm) {
    final formattedDist = distanceKm < 1.0
        ? '${(distanceKm * 1000).toStringAsFixed(0)} m'
        : '${distanceKm.toStringAsFixed(1)} km';

    // Estimasi waktu tempuh mobil/motor di jalan berkelok lereng (kecepatan rata-rata 25 km/jam)
    final int minutes = (distanceKm / 25 * 60).clamp(3, 180).round();
    return '$formattedDist ($minutes mnt)';
  }

  /// Menentukan status Kawasan Rawan Bencana (KRB) Merapi
  static String getKrbZone(double lat, double lng) {
    final dist = distanceFromMerapiSummit(lat, lng);
    if (dist < 3.0) {
      return 'KRB III (Zona Merah / < 3 km)';
    } else if (dist <= 5.0) {
      return 'KRB II (Zona Waspada / 3-5 km)';
    } else {
      return 'KRB I (Zona Aman / > 5 km)';
    }
  }

  /// Apakah lokasi berada dalam zona aman wisata (> 3 km dari puncak)
  static bool isSafeTourismZone(double lat, double lng) {
    return distanceFromMerapiSummit(lat, lng) >= 3.0;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }
}
