// pwa-install: the title page's one-click install toast.
import 'dart:async';

import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/install_prompt.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/install_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A browser that fires (or never fires) `beforeinstallprompt`.
class FakeInstallPrompt extends InstallPrompt {
  FakeInstallPrompt({this.offered = false, this.outcome});
  bool offered;
  bool _installed = false;
  int prompts = 0;
  final Completer<InstallOutcome>? outcome;

  @override
  bool get available => offered && !_installed;
  @override
  bool get installed => _installed;

  /// The browser fired `beforeinstallprompt`.
  void offer() {
    offered = true;
    notifyListeners();
  }

  /// `appinstalled`, or the page now runs as a standalone app.
  void install() {
    _installed = true;
    notifyListeners();
  }

  @override
  Future<InstallOutcome> prompt() async {
    prompts++;
    offered = false; // a deferred event prompts once
    notifyListeners();
    final result =
        await (outcome?.future ?? Future.value(InstallOutcome.dismissed));
    if (result == InstallOutcome.accepted) _installed = true;
    return result;
  }
}

class ThrowingStore implements LocalStore {
  @override
  String? read(String key) => throw StateError('blocked');
  @override
  void write(String key, String value) => throw StateError('blocked');
  @override
  void remove(String key) => throw StateError('blocked');
}

final _toast = find.byKey(const ValueKey('install-toast'));
final _install = find.byKey(const ValueKey('install-toast-install'));
final _close = find.byKey(const ValueKey('install-toast-close'));

Future<void> _pumpToast(
  WidgetTester tester,
  InstallPrompt prompt,
  InstallToastPolicy policy,
) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: InstallToast(prompt: prompt, policy: policy),
      ),
    ),
  ),
);

void main() {
  group('InstallToastPolicy', () {
    test('a fresh viewer is not snoozed', () {
      final policy = InstallToastPolicy(MemoryLocalStore());
      expect(policy.snoozed, isFalse);
      expect(policy.shows(FakeInstallPrompt(offered: true)), isTrue);
    });

    test('a dismissal snoozes for 90 days, then may ask once more', () {
      final store = MemoryLocalStore();
      var now = DateTime.utc(2026, 11, 15);
      InstallToastPolicy policy() => InstallToastPolicy(store, now: () => now);
      policy().rememberDismissal();
      expect(store.read(InstallToastPolicy.dismissedKey), isNotNull);
      now = now.add(const Duration(days: 89));
      expect(policy().snoozed, isTrue);
      now = now.add(const Duration(days: 2));
      expect(policy().snoozed, isFalse);
    });

    test('a dismissal stamped far in the future does not snooze forever', () {
      final store = MemoryLocalStore();
      store.write(
        InstallToastPolicy.dismissedKey,
        DateTime.utc(2030).millisecondsSinceEpoch.toString(),
      );
      final policy = InstallToastPolicy(
        store,
        now: () => DateTime.utc(2026, 11, 15),
      );
      expect(policy.snoozed, isFalse);
    });

    test('garbage in the store is ignored', () {
      final store = MemoryLocalStore()
        ..write(InstallToastPolicy.dismissedKey, 'not a time');
      expect(InstallToastPolicy(store).snoozed, isFalse);
    });

    test('a store that throws (private mode) never breaks the page', () {
      final policy = InstallToastPolicy(ThrowingStore());
      expect(policy.snoozed, isFalse);
      policy.rememberDismissal(); // no throw
      expect(policy.snoozed, isTrue, reason: 'held for this page view');
    });

    test('only an available, not-installed prompt shows', () {
      final policy = InstallToastPolicy(MemoryLocalStore());
      expect(policy.shows(FakeInstallPrompt()), isFalse);
      expect(policy.shows(NoInstallPrompt()), isFalse);
      final installed = FakeInstallPrompt(offered: true)..install();
      expect(policy.shows(installed), isFalse);
    });
  });

  group('InstallToast', () {
    testWidgets(
      'nothing at all where the browser offers no one-click install',
      (tester) async {
        // Safari (iOS, macOS) and Firefox never fire beforeinstallprompt.
        await _pumpToast(
          tester,
          FakeInstallPrompt(),
          InstallToastPolicy(MemoryLocalStore()),
        );
        expect(_toast, findsNothing);
        expect(find.textContaining('Share'), findsNothing);
        expect(find.textContaining('Home Screen'), findsNothing);
      },
    );

    testWidgets('appears when the browser offers it, with Install and ✕', (
      tester,
    ) async {
      final prompt = FakeInstallPrompt();
      await _pumpToast(tester, prompt, InstallToastPolicy(MemoryLocalStore()));
      expect(_toast, findsNothing);
      prompt.offer();
      await tester.pump();
      expect(_toast, findsOneWidget);
      expect(find.text('INSTALL'), findsOneWidget);
      expect(_close, findsOneWidget);
      // Small: one line, never wider than 360 px.
      expect(tester.getSize(_toast).width, lessThanOrEqualTo(360));
      expect(tester.getSize(_toast).height, lessThan(56));
    });

    testWidgets('one click on Install opens the browser approval', (
      tester,
    ) async {
      final store = MemoryLocalStore();
      final answer = Completer<InstallOutcome>();
      final prompt = FakeInstallPrompt(offered: true, outcome: answer);
      await _pumpToast(tester, prompt, InstallToastPolicy(store));
      await tester.tap(_install);
      await tester.pump();
      expect(prompt.prompts, 1);
      // Held (button disabled) while the browser's dialog is open.
      expect(_toast, findsOneWidget);
      await tester.tap(_install);
      await tester.pump();
      expect(prompt.prompts, 1);
      answer.complete(InstallOutcome.accepted);
      await tester.pumpAndSettle();
      expect(_toast, findsNothing);
      expect(
        store.read(InstallToastPolicy.dismissedKey),
        isNull,
        reason: 'an install is not a dismissal',
      );
    });

    testWidgets('declining the browser dialog snoozes like a dismissal', (
      tester,
    ) async {
      final store = MemoryLocalStore();
      final prompt = FakeInstallPrompt(offered: true);
      await _pumpToast(tester, prompt, InstallToastPolicy(store));
      await tester.tap(_install);
      await tester.pumpAndSettle();
      expect(_toast, findsNothing);
      expect(store.read(InstallToastPolicy.dismissedKey), isNotNull);
    });

    testWidgets('✕ hides it and it does not nag again on the next visit', (
      tester,
    ) async {
      final store = MemoryLocalStore();
      final prompt = FakeInstallPrompt(offered: true);
      await _pumpToast(tester, prompt, InstallToastPolicy(store));
      await tester.tap(_close);
      await tester.pump();
      expect(_toast, findsNothing);
      expect(prompt.prompts, 0);
      // Next page view (new policy, same viewer's store): still quiet.
      await tester.pumpWidget(const SizedBox());
      await _pumpToast(tester, prompt, InstallToastPolicy(store));
      prompt.offer();
      await tester.pump();
      expect(_toast, findsNothing);
    });

    testWidgets('hides when the app gets installed (appinstalled)', (
      tester,
    ) async {
      final prompt = FakeInstallPrompt(offered: true);
      await _pumpToast(tester, prompt, InstallToastPolicy(MemoryLocalStore()));
      expect(_toast, findsOneWidget);
      prompt.install();
      await tester.pump();
      expect(_toast, findsNothing);
    });
  });

  group('on the landing page', () {
    Future<FakeInstallPrompt> launch(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prompt = FakeInstallPrompt(offered: true);
      final scores = ScoreService(
        client: MockClient((_) async => http.Response('{"scores":[]}', 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ArcadePage(
            scoreService: scores,
            runStorage: RunStorage(store: MemoryLocalStore()),
            installPrompt: prompt,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return prompt;
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(1280, 720),
    ]) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('shows on the title, never over Start, at $tag', (
        tester,
      ) async {
        await launch(tester, size);
        expect(_toast.hitTestable(), findsOneWidget);
        final start = find.text('START GAME  →');
        await tester.ensureVisible(start);
        await tester.pump();
        expect(start.hitTestable(), findsOneWidget);
        final toast = tester.getRect(_toast);
        expect(toast.overlaps(tester.getRect(start)), isFalse);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('gone as soon as a run starts (never during gameplay)', (
      tester,
    ) async {
      await launch(tester, const Size(390, 844));
      expect(_toast, findsOneWidget);
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_toast, findsNothing);
      await unmount(tester);
    });
  });
}
