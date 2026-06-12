import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from `.env` via
/// `flutter_dotenv`. Call `dotenv.load(fileName: ".env")` before
/// reading these values.
abstract final class Env {
  static String get supabaseUrl => dotenv.get('SUPABASE_URL');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY');
}
