import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// ALMACENAMIENTO LOCAL
// Solo conserva preferencias, borradores y el trabajo actual del dispositivo.
// Los datos personales o sincronizables pertenecen a CloudStateStorage.
// =============================================================================

abstract interface class LocalStateStorage {
  Future<String?> read();
  Future<void> write(String json);
}

class PersistentLocalStateStorage implements LocalStateStorage {
  PersistentLocalStateStorage._(this._preferences);

  static const _key = 'simplestore_local_state_v2';
  static const _legacyKey = 'simplestore_state_v1';
  final SharedPreferences _preferences;

  static Future<PersistentLocalStateStorage> create() async {
    return PersistentLocalStateStorage._(await SharedPreferences.getInstance());
  }

  @override
  Future<String?> read() async {
    return _preferences.getString(_key) ?? _preferences.getString(_legacyKey);
  }

  @override
  Future<void> write(String json) async {
    await _preferences.setString(_key, json);
    await _preferences.remove(_legacyKey);
  }
}

// Se usa en pruebas y vistas previas para no escribir en el dispositivo.
class MemoryLocalStateStorage implements LocalStateStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    value = json;
  }
}
