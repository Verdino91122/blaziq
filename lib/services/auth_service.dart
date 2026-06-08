import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  /// Ensures the app always has a signed-in user with a Firestore doc.
  /// Called from main() before the app renders.
  static Future<String?> ensureAnonymousSignIn() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      if (_auth.currentUser == null) {
        return 'Auth succeeded but currentUser is null';
      }
      // Firestore doc is NOT created here — it is created lazily in
      // saveGameResult() only when the user actually completes a game.
      return null;
    } on FirebaseAuthException catch (e) {
      // Most common cause: Anonymous sign-in not enabled in Firebase Console →
      // Authentication → Sign-in method → Anonymous → Enable.
      return 'FirebaseAuth error: ${e.code} — ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Signs in with Google, handling three cases:
  /// 1. Anonymous user → tries to link the Google account (preserves UID + Firestore doc).
  /// 2. Link fails (Google account already exists) → migrates anon progress to Google account.
  /// 3. Non-anonymous user → fresh Google sign-in.
  /// Returns null if the user cancels or an unrecoverable error occurs.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final anonUser = _auth.currentUser;
      final isAnon = anonUser?.isAnonymous ?? false;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        if (isAnon) {
          try {
            final cred = await anonUser!.linkWithPopup(provider);
            await UserService.upgradeToGoogle(cred.user!);
            await _patchUsernameIfNeeded(cred.user!);
            return cred;
          } on FirebaseAuthException catch (e) {
            if ((e.code == 'credential-already-in-use' ||
                    e.code == 'email-already-in-use') &&
                e.credential != null) {
              final cred = await _migrateAndSignIn(
                anonUid: anonUser!.uid,
                credential: e.credential!,
              );
              if (cred?.user != null) await _patchUsernameIfNeeded(cred!.user!);
              return cred;
            }
            return null;
          }
        }
        final cred = await _auth.signInWithPopup(provider);
        if (cred.user != null) await _patchUsernameIfNeeded(cred.user!);
        return cred;
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        if (isAnon) {
          try {
            final cred = await anonUser!.linkWithCredential(credential);
            await UserService.upgradeToGoogle(cred.user!);
            await _patchUsernameIfNeeded(cred.user!);
            return cred;
          } on FirebaseAuthException catch (e) {
            if ((e.code == 'credential-already-in-use' ||
                    e.code == 'email-already-in-use') &&
                e.credential != null) {
              final cred = await _migrateAndSignIn(
                anonUid: anonUser!.uid,
                credential: e.credential!,
              );
              if (cred?.user != null) await _patchUsernameIfNeeded(cred!.user!);
              return cred;
            }
            return null;
          }
        }
        final cred = await _auth.signInWithCredential(credential);
        if (cred.user != null) await _patchUsernameIfNeeded(cred.user!);
        return cred;
      }
    } catch (_) {
      return null;
    }
  }

  /// Reads anon Firestore data, signs in as the existing Google account,
  /// merges progress, then deletes the orphaned anon doc.
  static Future<UserCredential?> _migrateAndSignIn({
    required String anonUid,
    required AuthCredential credential,
  }) async {
    final anonData = await UserService.getUserData(anonUid);
    final cred = await _auth.signInWithCredential(credential);
    if (cred.user == null) return null;
    await UserService.ensureUserDoc(cred.user!);
    if (anonData != null) {
      await UserService.mergeAnonData(
        googleUid: cred.user!.uid,
        anonData: anonData,
      );
    }
    await UserService.deleteUserDoc(anonUid).catchError((_) {});
    return cred;
  }

  /// If the Firestore username is 'Player' or blank, overwrites it with
  /// the real Google display name. Called after every successful Google sign-in.
  static Future<void> _patchUsernameIfNeeded(User user) async {
    if (user.isAnonymous) return;
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    if (displayName == null || displayName.isEmpty) return;
    final ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) return;
    final current = (doc.data()?['username'] as String?) ?? '';
    if (current.isEmpty || current == 'Player') {
      await ref.update({'username': displayName});
    }
  }

  /// Signs out and immediately re-enters anonymous auth so the app
  /// always has a signed-in user.
  static Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn().signOut();
    await _auth.signOut();
    await ensureAnonymousSignIn();
  }
}
