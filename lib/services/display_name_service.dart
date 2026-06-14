import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimResult { success, taken, error }

class DisplayNameService {
  static final _db = FirebaseFirestore.instance;

  static String? validateDisplayName(String name) {
    if (name.length < 3) return 'At least 3 characters';
    if (name.length > 20) return 'Maximum 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) {
      return 'Letters, numbers and underscores only';
    }
    return null;
  }

  static Future<ClaimResult> claimName(String uid, String displayName) async {
    final lowerName = displayName.toLowerCase();
    final nameRef = _db.collection('displayNames').doc(lowerName);
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final nameDoc = await tx.get(nameRef);
        if (nameDoc.exists &&
            nameDoc.data()!['uid'] != uid &&
            nameDoc.data()!['reserved'] != true) {
          throw Exception('NAME_TAKEN');
        }
        tx.set(nameRef, {
          'uid': uid,
          'displayName': displayName,
          'reserved': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          userRef,
          {
            'displayName': displayName,
            'lastNameChange': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      return ClaimResult.success;
    } catch (e) {
      if (e.toString().contains('NAME_TAKEN')) return ClaimResult.taken;
      return ClaimResult.error;
    }
  }

  // Mark old name as reserved (blocked) instead of deleting it.
  static Future<void> releaseName(String uid, String oldName) async {
    try {
      await _db
          .collection('displayNames')
          .doc(oldName.toLowerCase())
          .update({'reserved': true});
    } catch (_) {}
  }

  static Future<bool> isAvailable(String uid, String name) async {
    try {
      final doc =
          await _db.collection('displayNames').doc(name.toLowerCase()).get();
      if (!doc.exists) return true;
      final data = doc.data()!;
      if (data['uid'] == uid) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> canChangeName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final last = doc.data()?['lastNameChange'] as Timestamp?;
      if (last == null) return true;
      return DateTime.now().difference(last.toDate()).inDays >= 7;
    } catch (_) {
      return true;
    }
  }

  static int daysUntilCanChange(Timestamp lastNameChange) {
    final elapsed = DateTime.now().difference(lastNameChange.toDate()).inDays;
    return (7 - elapsed).clamp(1, 7);
  }

  static List<String> generateSuggestions(String baseName) {
    final pool = [
      'SwiftFox', 'BlazeKing', 'TriviaTitan', 'QuizMaster',
      'StarBlaze', 'NeonFox', 'ThunderQuiz', 'CosmicAce',
    ];
    final rng = Random();
    final clean = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final base = clean.isNotEmpty ? clean : pool[rng.nextInt(pool.length)];
    return [
      '$base${rng.nextInt(90) + 10}',
      '${base}_${rng.nextInt(9) + 1}',
      '${pool[rng.nextInt(pool.length)]}${rng.nextInt(90) + 10}',
      '${pool[rng.nextInt(pool.length)]}${rng.nextInt(90) + 10}',
    ].take(4).toList();
  }
}
