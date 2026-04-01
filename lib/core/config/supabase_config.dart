import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => _trim(dotenv.env['SUPABASE_URL']);

  static String get anonKey => _trim(dotenv.env['SUPABASE_ANON_KEY']);

  /// Évite espaces / guillemets parasites dans `.env` (sinon 401 sur les Edge Functions).
  static String _trim(String? value) {
    if (value == null) return '';
    var s = value.trim();
    if (s.length >= 2) {
      final q = s[0];
      if ((q == '"' || q == "'") && s.endsWith(q)) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    return s;
  }
}
