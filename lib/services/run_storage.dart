import 'dart:convert';

import '../game/difficulty.dart';
import 'run_storage_stub.dart'
    if (dart.library.js_interop) 'run_storage_web.dart'
    as platform;

abstract interface class LocalStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class MemoryLocalStore implements LocalStore {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
  @override
  void remove(String key) => values.remove(key);
}

class RunHistory {
  RunHistory({
    this.failures = 0,
    this.everBeatBoss = false,
    this.easyUnlocked = false,
    this.hardUnlocked = false,
  });
  int failures;
  bool everBeatBoss, easyUnlocked, hardUnlocked;

  bool unlocked(Difficulty difficulty) => switch (difficulty) {
    Difficulty.normal => true,
    Difficulty.easy => easyUnlocked || hardUnlocked,
    Difficulty.hard => hardUnlocked,
  };

  void recordFailure() {
    failures++;
    if (!everBeatBoss && failures >= 3) easyUnlocked = true;
  }

  void recordBoss(Difficulty difficulty) {
    everBeatBoss = true;
    if (difficulty == Difficulty.normal) {
      hardUnlocked = true;
      easyUnlocked = true;
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'failures': failures,
    'everBeatBoss': everBeatBoss,
    'easyUnlocked': easyUnlocked,
    'hardUnlocked': hardUnlocked,
  };

  factory RunHistory.fromJson(Map<String, dynamic> data) {
    final failures = data['failures'];
    final count = failures is int && failures >= 0 ? failures : 0;
    final everBeatBoss =
        data['everBeatBoss'] == true || data['hardUnlocked'] == true;
    return RunHistory(
      failures: count,
      everBeatBoss: everBeatBoss,
      easyUnlocked:
          data['easyUnlocked'] == true ||
          data['hardUnlocked'] == true ||
          (!everBeatBoss && count >= 3),
      hardUnlocked: data['hardUnlocked'] == true,
    );
  }
}

/// Writes only at wave entrances and terminal/history events, never per frame.
class RunStorage {
  RunStorage({LocalStore? store})
    : store = store ?? platform.createLocalStore();
  final LocalStore store;
  static const checkpointKey = 'demonAttack.checkpoint';
  static const historyKey = 'demonAttack.history';

  Map<String, dynamic>? _read(String key) {
    try {
      final value = store.read(key);
      if (value == null) return null;
      final data = jsonDecode(value);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? loadCheckpoint() => _read(checkpointKey);
  RunHistory loadHistory() => RunHistory.fromJson(_read(historyKey) ?? {});
  void saveCheckpoint(Map<String, dynamic> data) => _write(checkpointKey, data);
  void saveHistory(RunHistory history) => _write(historyKey, history.toJson());

  void _write(String key, Map<String, dynamic> data) {
    try {
      store.write(key, jsonEncode(data));
    } catch (_) {
      // Private browsing, denied storage and quota limits do not block play.
    }
  }

  void clearCheckpoint() {
    try {
      store.remove(checkpointKey);
    } catch (_) {
      // The current session remains playable when browser storage is denied.
    }
  }
}
