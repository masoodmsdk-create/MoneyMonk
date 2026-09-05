import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:moneymonk/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? get authUid => _auth?.currentUser?.uid;

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

  /// Returns the authenticated UID for cloud operations.
  /// Cloud access has no username or anonymous fallback.
  String? getUid() => authUid;

  /// Returns the namespace for local-only storage.
  /// Authenticated sessions use the Firebase UID. Offline sessions receive a
  /// locally generated namespace that is stored for that local account.
  Future<String> getLocalStorageUid(String username) async {
    await ensureInitialized();
    final normalized = username.trim().toLowerCase();
    final authenticatedEmail = _auth?.currentUser?.email?.toLowerCase();
    final authenticatedUsername = authenticatedEmail != null && authenticatedEmail.endsWith('@moneymonk.app')
        ? authenticatedEmail.substring(0, authenticatedEmail.length - '@moneymonk.app'.length)
        : null;
    if (authUid != null && authenticatedUsername == normalized) {
      return authUid!;
    }

    final preferences = await SharedPreferences.getInstance();
    final key = 'moneymonk_local_uid_$normalized';
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;

    final entropy = '$normalized:${DateTime.now().microsecondsSinceEpoch}';
    final generated = 'local_${sha256.convert(utf8.encode(entropy)).toString().substring(0, 24)}';
    await preferences.setString(key, generated);
    return generated;
  }

  /// Signs in or creates the Firebase Auth account for the MoneyMonk account.
  /// Returns false when Firebase is unavailable so local offline mode can work.
  Future<bool> authenticateAccount(String username, String password) async {
    await ensureInitialized();
    if (_auth == null) return false;
    final email = '${username.trim().toLowerCase()}@moneymonk.app';
    try {
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (_) {
      try {
        await _auth!.createUserWithEmailAndPassword(email: email, password: password);
        return true;
      } catch (e) {
        debugPrint('Firebase Auth notice: $e');
        return false;
      }
    }
  }

  /// Stores the account identity alongside its user-owned financial data.
  Future<bool> saveUserProfile(String username) async {
    await ensureInitialized();
    final uid = authUid;
    if (_firestore == null || uid == null) return false;
    try {
      await _firestore!.collection('users').doc(uid).collection('profile').doc('info').set({
        'uid': uid,
        'username': username.trim().toLowerCase(),
        'email': _auth!.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore saveUserProfile notice: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
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
