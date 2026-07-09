import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static VoidCallback? onSignOut;

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
      return null;
    } on FirebaseAuthException catch (e) {
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
            await _ensureDisplayName(cred.user!, null);
            await UserService.upgradeToGoogle(
              FirebaseAuth.instance.currentUser ?? cred.user!,
            );
            await _patchUsernameIfNeeded(
              FirebaseAuth.instance.currentUser ?? cred.user!,
            );
            return cred;
          } on FirebaseAuthException catch (e) {
            if ((e.code == 'credential-already-in-use' ||
                    e.code == 'email-already-in-use') &&
                e.credential != null) {
              final cred = await _migrateAndSignIn(
                anonUid: anonUser!.uid,
                credential: e.credential!,
                googleDisplayName: null,
              );
              if (cred?.user != null) {
                await _patchUsernameIfNeeded(
                  FirebaseAuth.instance.currentUser ?? cred!.user!,
                );
              }
              return cred;
            }
            return null;
          }
        }
        final cred = await _auth.signInWithPopup(provider);
        if (cred.user != null) {
          // Web popup may carry display name in additionalUserInfo
          final nameFromProfile =
              cred.additionalUserInfo?.profile?['name'] as String?;
          await _ensureDisplayName(cred.user!, nameFromProfile);
          await _patchUsernameIfNeeded(
            FirebaseAuth.instance.currentUser ?? cred.user!,
          );
        }
        return cred;
      } else {
        final googleUser = await GoogleSignIn(
          scopes: ['email', 'profile'],
        ).signIn();
        if (googleUser == null) return null;

        // Capture displayName from the Google SDK object NOW — it becomes
        // null on the Firebase User after signInWithCredential on the
        // migration path (credential-already-in-use fallback).
        final googleDisplayName = googleUser.displayName;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        if (isAnon) {
          try {
            final cred = await anonUser!.linkWithCredential(credential);
            await _ensureDisplayName(cred.user!, googleDisplayName);
            await UserService.upgradeToGoogle(
              FirebaseAuth.instance.currentUser ?? cred.user!,
            );
            await _patchUsernameIfNeeded(
              FirebaseAuth.instance.currentUser ?? cred.user!,
            );
            return cred;
          } on FirebaseAuthException catch (e) {
            if ((e.code == 'credential-already-in-use' ||
                    e.code == 'email-already-in-use') &&
                e.credential != null) {
              final cred = await _migrateAndSignIn(
                anonUid: anonUser!.uid,
                credential: e.credential!,
                googleDisplayName: googleDisplayName,
              );
              if (cred?.user != null) {
                await _patchUsernameIfNeeded(
                  FirebaseAuth.instance.currentUser ?? cred!.user!,
                );
              }
              return cred;
            }
            return null;
          }
        }

        final cred = await _auth.signInWithCredential(credential);
        if (cred.user != null) {
          await _ensureDisplayName(cred.user!, googleDisplayName);
          await _patchUsernameIfNeeded(
            FirebaseAuth.instance.currentUser ?? cred.user!,
          );
        }
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
    required String? googleDisplayName,
  }) async {
    final anonData = await UserService.getUserData(anonUid);
    final cred = await _auth.signInWithCredential(credential);
    if (cred.user == null) return null;

    // Firebase doesn't populate displayName after signInWithCredential on the
    // migration path. Force it from the Google SDK value captured before sign-in.
    await _ensureDisplayName(cred.user!, googleDisplayName);

    await UserService.ensureUserDoc(
      FirebaseAuth.instance.currentUser ?? cred.user!,
    );
    if (anonData != null) {
      await UserService.mergeAnonData(
        googleUid: cred.user!.uid,
        anonData: anonData,
      );
    }
    await UserService.deleteUserDoc(anonUid).catchError((_) {});
    return cred;
  }

  /// Writes [fallbackName] to the Firebase user profile when displayName is
  /// missing, then reloads so subsequent reads see the correct value.
  static Future<void> _ensureDisplayName(
    User user,
    String? fallbackName,
  ) async {
    final current = FirebaseAuth.instance.currentUser;
    final hasName = (current?.displayName ?? user.displayName ?? '').isNotEmpty;
    if (!hasName && fallbackName != null && fallbackName.isNotEmpty) {
      await (current ?? user).updateDisplayName(fallbackName);
      await FirebaseAuth.instance.currentUser?.reload();
    }
  }

  /// If the Firestore username is 'Player' or blank, overwrites it with
  /// the real Google display name. Called after every successful Google sign-in.
  static Future<void> _patchUsernameIfNeeded(User user) async {
    if (user.isAnonymous) return;
    final displayName =
        FirebaseAuth.instance.currentUser?.displayName ?? user.displayName;
    if (displayName == null || displayName.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) return;
    final current = (doc.data()?['username'] as String?) ?? '';
    if (current.isEmpty || current == 'Player') {
      await ref.update({'username': displayName});
      try {
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(user.uid)
            .update({'username': displayName});
      } catch (_) {}
    }
  }

  /// Signs out and immediately re-enters anonymous auth so the app
  /// always has a signed-in user.
  static Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn().signOut();
    await _auth.signOut();
    await ensureAnonymousSignIn();
    onSignOut?.call();
  }

  /// Permanently deletes the current user's account:
  ///   1. Wipes all Firestore data (user doc, leaderboard, display-name claim).
  ///   2. Attempts to delete the Firebase Auth account. If Firebase rejects the
  ///      call (e.g. requires-recent-login), we sign out instead — the Auth
  ///      record becomes an orphaned, dataless shell with no user impact.
  ///   3. Re-enters anonymous auth so the app always has a signed-in user.
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Firestore data is always deleted first — this succeeds regardless of
    // how long ago the user signed in.
    await UserService.deleteAccountData(uid);

    // Attempt to remove the Firebase Auth account. On failure (most commonly
    // requires-recent-login) we simply sign out; the empty Auth record is
    // harmless because all data is already gone.
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
      await user.delete();
    } catch (e) {
      debugPrint('[Blaziq] deleteAccount: Auth delete failed ($e), signing out instead');
      await _auth.signOut().catchError((_) {});
    }

    await ensureAnonymousSignIn();
    onSignOut?.call();
  }
}
