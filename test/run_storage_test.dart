import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class DeniedStore implements LocalStore {
  @override
  String? read(String key) => throw StateError('Denied');
  @override
  void write(String key, String value) => throw StateError('Denied');
  @override
  void remove(String key) => throw StateError('Denied');
}

void main() {
  test(
    'unlock history distinguishes failure, Easy victory and Normal victory',
    () {
      final history = RunHistory();
      history.recordFailure();
      history.recordFailure();
      expect(history.easyUnlocked, isFalse);
      history.recordFailure();
      expect(history.easyUnlocked, isTrue);
      history.recordBoss(Difficulty.easy);
      expect(history.hardUnlocked, isFalse);
      history.recordBoss(Difficulty.normal);
      final restored = RunHistory.fromJson(history.toJson());
      expect(restored.easyUnlocked, isTrue);
      expect(restored.hardUnlocked, isTrue);
      expect(restored.everBeatBoss, isTrue);
      final successful = RunHistory()..recordBoss(Difficulty.normal);
      for (var i = 0; i < 5; i++) {
        successful.recordFailure();
      }
      expect(successful.easyUnlocked, isFalse);
    },
  );

  test(
    'storage roundtrips compact checkpoints and permanently separate history',
    () {
      final store = MemoryLocalStore();
      final storage = RunStorage(store: store);
      final model = ArcadeModel()..start(difficulty: Difficulty.easy);
      storage.saveCheckpoint(model.checkpoint());
      storage.saveHistory(RunHistory(easyUnlocked: true, hardUnlocked: true));
      final restored = ArcadeModel();
      expect(restored.restoreCheckpoint(storage.loadCheckpoint()!), isTrue);
      expect(restored.difficulty, Difficulty.easy);
      expect(restored.lives, 5);
      expect(jsonEncode(storage.loadCheckpoint()).length, lessThan(1024));
      storage.clearCheckpoint();
      expect(storage.loadCheckpoint(), isNull);
      expect(storage.loadHistory().hardUnlocked, isTrue);
    },
  );

  test('corrupt or denied storage leaves defaults and writes safe', () {
    final store = MemoryLocalStore();
    store.values[RunStorage.checkpointKey] = '{not json';
    store.values[RunStorage.historyKey] = '[]';
    final storage = RunStorage(store: store);
    expect(storage.loadCheckpoint(), isNull);
    expect(storage.loadHistory().unlocked(Difficulty.normal), isTrue);
    final denied = RunStorage(store: DeniedStore());
    expect(denied.loadCheckpoint(), isNull);
    expect(denied.loadHistory().easyUnlocked, isFalse);
    denied.saveCheckpoint({'score': 5});
    denied.saveHistory(RunHistory());
    denied.clearCheckpoint();
  });
}
