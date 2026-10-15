/// Konfigurasi Supabase untuk aplikasi MeraTrip.
/// Nilai URL dan Publishable Key diambil dari konfigurasi project Supabase Anda.
/// CATATAN KEAMANAN: Hanya gunakan Publishable Key / Anon Key.
/// JANGAN PERNAH menyertakan secret_key atau service_role_key di aplikasi Flutter (client-side).
class SupabaseConfig {
  /// Supabase Project URL
  static const String url = 'https://xdwkvtwwipbpwkipmtjk.supabase.co';

  /// Supabase Publishable / Anon Key
  static const String anonKey = 'sb_publishable_b-45mXWI5krktOEAerJDqw_vZ9FKBjd';

  /// Memeriksa apakah konfigurasi Supabase valid dan telah diisi
  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR_PROJECT') &&
      !anonKey.contains('YOUR_ANON_KEY');
}
