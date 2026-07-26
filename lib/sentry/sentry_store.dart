// sentry_store.dart - Persistencia compartida entre UI y WorkManager.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sentry_models.dart';

class SentryStore {
  static const _kArmed = 'sentry_armed';
  static const _kVin = 'sentry_vin';
  static const _kBaseline = 'sentry_baseline';
  static const _kLast = 'sentry_last';
  static const _kConfig = 'sentry_config';
  static const _kLog = 'sentry_log';
  static const _kOnline = 'sentry_online';
  static const _kDeterrentAt = 'sentry_deterrent_at';
  static const _maxLog = 200;

  Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  Future<bool> loadArmed() async => (await _p).getBool(_kArmed) ?? false;
  Future<void> saveArmed(bool v) async => (await _p).setBool(_kArmed, v);

  Future<String?> loadVin() async => (await _p).getString(_kVin);
  Future<void> saveVin(String v) async => (await _p).setString(_kVin, v);

  Future<SentrySnapshot?> _loadSnap(String key) async {
    final s = (await _p).getString(key);
    if (s == null) return null;
    try {
      return SentrySnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSnap(String key, SentrySnapshot? snap) async {
    final p = await _p;
    if (snap == null) {
      await p.remove(key);
    } else {
      await p.setString(key, jsonEncode(snap.toJson()));
    }
  }

  Future<SentrySnapshot?> loadBaseline() => _loadSnap(_kBaseline);
  Future<void> saveBaseline(SentrySnapshot? s) => _saveSnap(_kBaseline, s);
  Future<SentrySnapshot?> loadLast() => _loadSnap(_kLast);
  Future<void> saveLast(SentrySnapshot? s) => _saveSnap(_kLast, s);

  Future<SentryConfig> loadConfig() async {
    final s = (await _p).getString(_kConfig);
    if (s == null) return const SentryConfig();
    try {
      return SentryConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const SentryConfig();
    }
  }

  Future<void> saveConfig(SentryConfig c) async =>
      (await _p).setString(_kConfig, jsonEncode(c.toJson()));

  Future<bool> loadOnline() async => (await _p).getBool(_kOnline) ?? true;
  Future<void> saveOnline(bool v) async => (await _p).setBool(_kOnline, v);

  Future<DateTime?> loadDeterrentAt() async {
    final ms = (await _p).getInt(_kDeterrentAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveDeterrentAt(DateTime t) async =>
      (await _p).setInt(_kDeterrentAt, t.millisecondsSinceEpoch);

  Future<List<SentryEvent>> loadLog() async {
    final s = (await _p).getString(_kLog);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => SentryEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendLog(List<SentryEvent> events) async {
    if (events.isEmpty) return;
    final log = await loadLog();
    log.insertAll(0, events);
    while (log.length > _maxLog) {
      log.removeLast();
    }
    await (await _p)
        .setString(_kLog, jsonEncode(log.map((e) => e.toJson()).toList()));
  }

  Future<void> clearLog() async => (await _p).remove(_kLog);
}
