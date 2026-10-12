import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// =============================================================================
// CONFIGURACIÓN DE FIREBASE
// Los valores se inyectan con --dart-define y nunca se guardan en el repositorio.
// =============================================================================

class FirebaseEnvironment {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}

// =============================================================================
// CUENTA Y CONTRATO DEL ESTADO REMOTO
// =============================================================================

class CloudAccount {
  const CloudAccount({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.isAnonymous,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool isAnonymous;

  String get initials {
    final words = displayName.trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'isAnonymous': isAnonymous,
  };

  factory CloudAccount.fromFirebaseUser(User user) {
    final email = user.email ?? '';
    final fallbackName = email.contains('@')
        ? email.split('@').first
        : 'Invitado';
    return CloudAccount(
      uid: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : fallbackName,
      email: email,
      isAnonymous: user.isAnonymous,
    );
  }
}

abstract interface class CloudStateStorage {
  bool get isAvailable;
  String get unavailableReason;
  CloudAccount? get account;

  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> json);
}

// =============================================================================
// IMPLEMENTACIÓN FIREBASE AUTH + CLOUD FIRESTORE
// =============================================================================

class FirebaseCloudStateStorage implements CloudStateStorage {
  FirebaseCloudStateStorage._({
    required FirebaseFirestore firestore,
    required this.account,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  final CloudAccount account;

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => '';

  DocumentReference<Map<String, dynamic>> get _userDocument =>
      _firestore.collection('users').doc(account.uid);

  static Future<CloudStateStorage> create() async {
    if (!FirebaseEnvironment.isConfigured) {
      return const DisabledCloudStateStorage(
        'Firebase todavía no está configurado.',
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseEnvironment.options);
      }

      final auth = FirebaseAuth.instance;
      final credential = auth.currentUser == null
          ? await auth.signInAnonymously()
          : null;
      final user = credential?.user ?? auth.currentUser;
      if (user == null) {
        return const DisabledCloudStateStorage(
          'No se pudo identificar la cuenta de Firebase.',
        );
      }

      return FirebaseCloudStateStorage._(
        firestore: FirebaseFirestore.instance,
        account: CloudAccount.fromFirebaseUser(user),
      );
    } on FirebaseException catch (error) {
      return DisabledCloudStateStorage(
        'Firebase no está disponible (${error.code}).',
      );
    } catch (_) {
      return const DisabledCloudStateStorage(
        'Firebase no está disponible en este momento.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final snapshot = await _userDocument.get();
    final value = snapshot.data()?['cloudState'];
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry('$key', value));
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    await _userDocument.set({
      'profile': account.toJson(),
      'cloudState': json,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// =============================================================================
// IMPLEMENTACIONES SIN RED PARA APP NO CONFIGURADA Y PRUEBAS
// =============================================================================

class DisabledCloudStateStorage implements CloudStateStorage {
  const DisabledCloudStateStorage(this.unavailableReason);

  @override
  final String unavailableReason;

  @override
  CloudAccount? get account => null;

  @override
  bool get isAvailable => false;

  @override
  Future<Map<String, dynamic>?> read() async => null;

  @override
  Future<void> write(Map<String, dynamic> json) async {}
}

class MemoryCloudStateStorage implements CloudStateStorage {
  MemoryCloudStateStorage({CloudAccount? account})
    : account =
          account ??
          const CloudAccount(
            uid: 'test-user',
            displayName: 'Usuario de prueba',
            email: 'test@example.com',
            isAnonymous: false,
          );

  Map<String, dynamic>? value;

  @override
  final CloudAccount account;

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => '';

  @override
  Future<Map<String, dynamic>?> read() async {
    if (value == null) return null;
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    value = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }
}
