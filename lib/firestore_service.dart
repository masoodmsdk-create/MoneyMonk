import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:moneymonk/main.dart';

/// Permanent Cloud Persistence Service for MoneyMonk using Cloud Firestore.
///
/// Ensures financial records belong to the user's account and are persisted
/// securely in the cloud under users/{uid}/..., while preserving local caching
/// and offline resilience.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyAracfPoWr9Hy5SlDqo8lanJnqI1LiLLc4',
    appId: '1:74922722939:web:a7b41121a546de5f9c44de',
    messagingSenderId: '74922722939',
    projectId: 'moneymonk-d5605',
    authDomain: 'moneymonk-d5605.firebaseapp.com',
    storageBucket: 'moneymonk-d5605.firebasestorage.app',
    measurementId: 'G-Q47HBRFRXH',
  );

  bool _initialized = false;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  bool disableForTesting = false;

  bool get isAvailable => _firestore != null && !disableForTesting;

  /// Initializes Firebase and Firestore instance safely.
  Future<void> ensureInitialized() async {
    if (disableForTesting || _initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _initialized = true;
      debugPrint('FirestoreService initialized successfully with project ${firebaseOptions.projectId}');
    } catch (e) {
      _initialized = true;
      debugPrint('FirestoreService notice (operating in local fallback mode): $e');
    }
  }

  /// Resolves the cloud ownership boundary UID for the given account username.
  /// If Firebase Auth is authenticated, returns the user's Auth UID.
  /// Otherwise, computes a stable deterministic account UID for that username.
  String getUid(String username) {
    if (_auth?.currentUser != null && _auth!.currentUser!.uid.isNotEmpty) {
      return _auth!.currentUser!.uid;
    }
    final normalized = username.trim().toLowerCase();
    final hash = sha256.convert(utf8.encode('moneymonk:account:$normalized')).toString();
    return 'user_${hash.substring(0, 24)}';
  }

  /// Attempts Firebase Authentication sign-in/up if enabled.
  Future<void> authenticateAccount(String username, String password) async {
    await ensureInitialized();
    if (_auth == null) return;
    final email = '${username.trim().toLowerCase()}@moneymonk.app';
    try {
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      try {
        await _auth!.createUserWithEmailAndPassword(email: email, password: password);
      } catch (_) {}
    }
  }

  /// Loads all MoneyEntry documents for this user from Firestore.
  Future<List<MoneyEntry>> loadMoney(String uid) async {
    await ensureInitialized();
    if (_firestore == null) return [];
    try {
      final snap = await _firestore!
          .collection('users')
          .doc(uid)
          .collection('money')
          .get(const GetOptions(source: Source.serverAndCache));
      
      final result = <MoneyEntry>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          result.add(MoneyEntry.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing cloud money doc ${doc.id}: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('Firestore loadMoney notice: $e');
      return [];
    }
  }

  /// Loads all LoanEntry documents for this user from Firestore.
  Future<List<LoanEntry>> loadLoans(String uid) async {
    await ensureInitialized();
    if (_firestore == null) return [];
    try {
      final snap = await _firestore!
          .collection('users')
          .doc(uid)
          .collection('loans')
          .get(const GetOptions(source: Source.serverAndCache));
      
      final result = <LoanEntry>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          result.add(LoanEntry.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing cloud loan doc ${doc.id}: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('Firestore loadLoans notice: $e');
      return [];
    }
  }

  /// Saves a single MoneyEntry to Firestore cloud storage.
  Future<bool> saveMoney(String uid, MoneyEntry entry) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      final json = entry.toJson();
      json['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('money')
          .doc(entry.id)
          .set(json, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore saveMoney notice: $e');
      return false;
    }
  }

  /// Deletes a MoneyEntry from Firestore cloud storage.
  Future<bool> deleteMoney(String uid, String entryId) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('money')
          .doc(entryId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Firestore deleteMoney notice: $e');
      return false;
    }
  }

  /// Saves a single LoanEntry to Firestore cloud storage.
  Future<bool> saveLoan(String uid, LoanEntry loan) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      final json = loan.toJson();
      json['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('loans')
          .doc(loan.id)
          .set(json, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore saveLoan notice: $e');
      return false;
    }
  }

  /// Deletes a LoanEntry from Firestore cloud storage.
  Future<bool> deleteLoan(String uid, String loanId) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('loans')
          .doc(loanId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Firestore deleteLoan notice: $e');
      return false;
    }
  }

  /// Batch saves a full dataset of Money and Loans (e.g. for migration or restore).
  Future<bool> batchSaveAll(String uid, List<MoneyEntry> moneyList, List<LoanEntry> loanList) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      final batch = _firestore!.batch();
      for (final entry in moneyList) {
        final docRef = _firestore!.collection('users').doc(uid).collection('money').doc(entry.id);
        final json = entry.toJson();
        json['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, json, SetOptions(merge: true));
      }
      for (final loan in loanList) {
        final docRef = _firestore!.collection('users').doc(uid).collection('loans').doc(loan.id);
        final json = loan.toJson();
        json['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, json, SetOptions(merge: true));
      }
      final infoRef = _firestore!.collection('users').doc(uid).collection('profile').doc('info');
      batch.set(infoRef, {
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'moneyCount': moneyList.length,
        'loansCount': loanList.length,
      }, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Firestore batchSaveAll notice: $e');
      return false;
    }
  }

  /// Permanently deletes all financial records belonging to [uid] from Firestore.
  Future<bool> deleteAllData(String uid) async {
    await ensureInitialized();
    if (_firestore == null) return false;
    try {
      final moneyDocs = await _firestore!.collection('users').doc(uid).collection('money').get();
      final loanDocs = await _firestore!.collection('users').doc(uid).collection('loans').get();
      
      final batch = _firestore!.batch();
      for (final doc in moneyDocs.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in loanDocs.docs) {
        batch.delete(doc.reference);
      }
      final infoRef = _firestore!.collection('users').doc(uid).collection('profile').doc('info');
      batch.set(infoRef, {
        'deletedAt': FieldValue.serverTimestamp(),
        'moneyCount': 0,
        'loansCount': 0,
      });

      await batch.commit();
      debugPrint('Successfully deleted all Firestore financial records for $uid');
      return true;
    } catch (e) {
      debugPrint('Firestore deleteAllData notice: $e');
      return false;
    }
  }
}
