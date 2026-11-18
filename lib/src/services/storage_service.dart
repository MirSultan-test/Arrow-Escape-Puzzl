import 'package:shared_preferences/shared_preferences.dart';
import '../models/save_data.dart';

/// Local persistence service managing versioned save data and preferences.
class StorageService {
  static const String _saveKey = 'parcel_escape_save_v1';
  SharedPreferences? _prefs;

  StorageService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Loads the persisted save data, recovering safely from corrupted or missing storage.
  Future<SaveData> loadSaveData() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_saveKey);
      return SaveData.fromJsonString(raw);
    } catch (_) {
      return const SaveData();
    }
  }

  /// Persists the active save data snapshot to local disk.
  Future<bool> persistSaveData(SaveData data) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setString(_saveKey, data.toJsonString());
    } catch (_) {
      return false;
    }
  }

  /// Resets saved gameplay progress while safely keeping privacy choices and age declarations.
  Future<SaveData> resetProgressPreservingPrivacy() async {
    final current = await loadSaveData();
    final reset = current.resetProgressOnly();
    await persistSaveData(reset);
    return reset;
  }

  /// Clears the entire storage key (for testing or complete wipe).
  Future<bool> clearAll() async {
    try {
      final prefs = await _getPrefs();
      return await prefs.remove(_saveKey);
    } catch (_) {
      return false;
    }
  }
}
