import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

/// Emits whenever the Supabase auth session changes (sign in, sign out,
/// token refresh). Used by the router to drive redirects.
@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

/// Drives sign in / sign up / sign out actions and exposes their
/// loading/error state to the auth screens.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  /// Returns `true` if a session was created immediately (email
  /// confirmation disabled), or `false` if the user must confirm their
  /// email before signing in.
  Future<bool> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    var hasSession = false;
    state = await AsyncValue.guard(() async {
      final response =
          await _client.auth.signUp(email: email, password: password);
      hasSession = response.session != null;
    });
    return hasSession;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final webClientId = dotenv.env['SUPABASE_WEB_CLIENT_ID'] ?? '';
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) throw Exception('No ID token from Google');

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signOut();
    });
  }
}
