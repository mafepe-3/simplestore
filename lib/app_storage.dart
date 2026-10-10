import 'package:shared_preferences/shared_preferences.dart';

// Este archivo solo se ocupa de guardar y recuperar el texto JSON.
// No conoce pantallas, productos ni reglas de negocio.
abstract interface class StateStorage {
  Future<String?> read();
  Future<void> write(String json);
}

class PersistentStateStorage implements StateStorage {
  PersistentStateStorage._(this._preferences);

  static const _key = 'simplestore_state_v1';
  final SharedPreferences _preferences;

  static Future<PersistentStateStorage> create() async {
    return PersistentStateStorage._(await SharedPreferences.getInstance());
  }

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<void> write(String json) async {
    await _preferences.setString(_key, json);
  }
}

// Se usa en pruebas y vistas previas para no escribir en el dispositivo.
class MemoryStateStorage implements StateStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    value = json;
  }
}
