import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/config/supabase_config.dart';
import 'package:project/core/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SupabaseConfig has valid url and publishableKey', () {
    expect(SupabaseConfig.url, 'https://xdwkvtwwipbpwkipmtjk.supabase.co');
    expect(SupabaseConfig.anonKey, 'sb_publishable_b-45mXWI5krktOEAerJDqw_vZ9FKBjd');
    expect(SupabaseConfig.isConfigured, true);
  });

  test('SupabaseService instance is created and ready', () {
    final service = SupabaseService();
    expect(service, isNotNull);
  });
}
