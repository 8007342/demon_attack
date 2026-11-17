/// portrait-comms-lanes (openspec/changes/portrait-comms-lanes): the
/// portrait radio dock's two independent lanes (humans left, brood right),
/// the fixed toast size, the combined comeback toast and its pairing rule,
/// and a level transition's radio chatter over the clouds.
library;

import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lanes.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/comms_transition_chatter.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:flutter/rendering.dart' show BoxParentData;
import 'package:demon_attack/game/model.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show dispose, launch;

final _human = commsCast.values.firstWhere((c) => !c.isDemon);
final _demon = commsCast.values.firstWhere((c) => c.isDemon);

const _trigger = CommsTriggerSpec(
  name: 'x',
  priority: 1,
  cooldown: 1,
  ttl: 10,
  lines: [],
);

CommsMessage _msg(
  String id,
  CommsCharacter who,
  double start, {
  String text = 'Hold the line!',
  double duration = 1,
  bool started = true,
}) {
  final m = CommsMessage(
    trigger: _trigger,
    line: CommsLine(
      id: id,
      speaker: who.id,
      duration: duration,
      text: who.isDemon ? null : text,
      grunt: who.isDemon ? 'gloat' : null,
      gloss: who.isDemon ? text : null,
    ),
    character: who,
    priority: 1,
    queuedAt: start,
    readyAt: start,
    expiresAt: start + 10,
    sequence: 0,
  );
  if (started) m.startedAt = start;
  return m;
}

/// Syncs [lanes] every 1/60 s from [from] to [to] (bounded), calling
/// [each] after every step.
void _run(
  CommsLanes lanes,
  List<CommsMessage> active,
  double from,
  double to, {
  List<CommsMessage> queue = const [],
  void Function(double now)? each,
}) {
  final steps = ((to - from) * 60).ceil();
  for (var i = 0; i <= steps; i++) {
    final now = from + i / 60;
    lanes.sync(now, active, queue: queue);
    each?.call(now);
  }
}

void main() {
  group('two independent lanes', () {
    test('the left toast closes in place and the right one stays put', () {
      final lanes = CommsLanes();
      final a = _msg('a', _human, 0, text: 'Go!');
      final b = _msg('b', _demon, .5, text: 'Your turn is mine, pilot!');
      final active = [a, b];
      _run(lanes, active, 0, .6);
      final left = lanes.toast(CommsLane.human)!;
      final right = lanes.toast(CommsLane.demon)!;
      expect(left.messages.single, same(a));
      expect(right.messages.single, same(b));
      final shownAt = right.shownAt;
      // Run until the human toast has closed (its own timeout), checking
      // that the brood toast never moves or changes.
      _run(
        lanes,
        active,
        .6,
        a.endsAt + .1,
        each: (now) {
          expect(lanes.toast(CommsLane.demon), same(right));
          expect(
            lanes.toast(CommsLane.human)?.messages.single.isDemon,
            isNot(true),
          );
        },
      );
      expect(lanes.toast(CommsLane.human), isNull);
      expect(lanes.toast(CommsLane.demon), same(right));
      expect(right.shownAt, shownAt);
      expect(b.endsAt, greaterThan(a.endsAt));
      _run(lanes, active, a.endsAt + .1, b.endsAt + .1);
      expect(lanes.toast(CommsLane.demon), isNull);
    });

    test('a second line of one side waits for its own lane', () {
      final lanes = CommsLanes();
      final a = _msg('a', _human, 0);
      final b = _msg('b', _human, 1.5, text: 'Missile up, break left!');
      final active = [a, b];
      _run(lanes, active, 0, 2);
      expect(lanes.toast(CommsLane.human)!.messages.single, same(a));
      expect(lanes.waiting(CommsLane.human), 1);
      expect(lanes.toast(CommsLane.demon), isNull, reason: 'never borrowed');
      _run(lanes, active, 2, a.endsAt + .05);
      final t = lanes.toast(CommsLane.human)!;
      expect(t.messages.single, same(b));
      // Its own persistence: at least its reading time from when it showed.
      expect(
        t.endsAt(a.endsAt + .05),
        greaterThanOrEqualTo(t.shownAt + CommsMessage.readingTime(b.line)),
      );
    });

    test('the brood is always on the right, humans on the left', () {
      for (final who in commsCast.values) {
        expect(
          CommsLanes.laneOf(who),
          who.isDemon ? CommsLane.demon : CommsLane.human,
        );
      }
    });

    test('stale lines are dropped; at most two wait per lane', () {
      final lanes = CommsLanes();
      final msgs = [for (var i = 0; i < 6; i++) _msg('h$i', _human, i * .1)];
      lanes.sync(.6, msgs);
      expect(lanes.waiting(CommsLane.human), CommsLanes.maxWaiting);
      lanes.sync(60, msgs);
      expect(lanes.waiting(CommsLane.human), 0);
    });
  });

  group('the comeback toast and its pairing rule', () {
    test('an exchange takes one toast across both lanes', () {
      final lanes = CommsLanes();
      final opening = _msg('o', _human, 0, text: 'That sector is ours!');
      final answer = _msg(
        'r',
        _demon,
        0,
        started: false,
        text: 'Not for long!',
      );
      opening.reply = answer;
      answer.inReplyTo = opening;
      final queue = [answer];
      lanes.sync(.1, [opening], queue: queue);
      final t = lanes.toast(CommsLane.human)!;
      expect(lanes.toast(CommsLane.demon), same(t));
      expect(t.half(CommsLane.human), same(opening));
      expect(t.half(CommsLane.demon), same(answer));
      // The queued answer keeps it up past the opening's own end.
      lanes.sync(opening.endsAt + .1, [opening], queue: queue);
      expect(lanes.toast(CommsLane.demon), same(t));
      answer.startedAt = opening.endsAt + .2;
      _run(lanes, [opening, answer], answer.startedAt, answer.endsAt - .05);
      expect(lanes.toast(CommsLane.human), same(t));
      lanes.sync(answer.endsAt + .01, [opening, answer]);
      expect(lanes.toast(CommsLane.human), isNull);
      expect(lanes.toast(CommsLane.demon), isNull);
    });

    test('demon first: the brood half stays on the right', () {
      final opening = _msg('o', _demon, 0, text: 'Run, little pilot!');
      final answer = _msg('r', _human, 1.5, text: 'Make me!')
        ..inReplyTo = opening;
      final lanes = CommsLanes()..sync(1.6, [opening, answer]);
      final t = lanes.toast(CommsLane.human)!;
      expect(t.pair, isTrue);
      expect(t.half(CommsLane.demon), same(opening));
      expect(t.half(CommsLane.human), same(answer));
    });

    test('a read occupant closes at once; an unread one after pairWait', () {
      // Read: the brood line has been up for its reading time.
      final lanes = CommsLanes();
      final taunt = _msg('d', _demon, 0, text: 'Hah!');
      _run(lanes, [taunt], 0, 2);
      expect(lanes.toast(CommsLane.demon), isNotNull);
      final opening = _msg('o', _human, 2, text: 'Save some for me!');
      final answer = _msg('r', _demon, 0, started: false)..inReplyTo = opening;
      opening.reply = answer;
      lanes.sync(2, [taunt, opening], queue: [answer]);
      final closing = lanes.toast(CommsLane.demon)!;
      expect(closing.closedAt, closeTo(2 + CommsLanes.fade, 1e-9));
      // A new human line queued behind the pair never jumps ahead.
      final late = _msg('l', _human, 2.05, text: 'Two more!');
      _run(
        lanes,
        [taunt, opening, late],
        2,
        2 + CommsLanes.fade + .02,
        queue: [answer],
      );
      final pair = lanes.toast(CommsLane.human)!;
      expect(pair.pair, isTrue);
      expect(lanes.toast(CommsLane.demon), same(pair));
      expect(lanes.waiting(CommsLane.human), 1);

      // Unread: the brood line has only just appeared.
      final lanes2 = CommsLanes();
      final fresh = _msg('d2', _demon, 0, text: 'x' * 80, duration: .5);
      lanes2.sync(0, [fresh]);
      final opening2 = _msg('o2', _human, .1, text: 'Cover me!');
      final answer2 = _msg('r2', _demon, 0, started: false)
        ..inReplyTo = opening2;
      opening2.reply = answer2;
      double? placed;
      _run(
        lanes2,
        [fresh, opening2],
        .1,
        3,
        queue: [answer2],
        each: (now) {
          final t = lanes2.toast(CommsLane.human);
          if (placed == null && t != null && t.pair) placed = now;
        },
      );
      expect(placed, isNotNull);
      expect(
        placed!,
        closeTo(.1 + CommsLanes.pairWait + CommsLanes.fade, 2 / 60),
      );
    });
  });

  group('fixed toast size', () {
    Future<void> pump(WidgetTester tester, CommsDirector d, double now) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: CommsHudStack(director: d, now: now),
              ),
            ),
          ),
        );

    testWidgets('short and long toasts share one size and never grow', (
      tester,
    ) async {
      final d = CommsDirector();
      final short = _msg('s', _demon, 0, text: 'Hah!');
      d.active.add(short);
      await pump(tester, d, .2);
      final alone = tester.getRect(find.byKey(const ValueKey('comms-strip-s')));
      expect(alone.height, CommsHudStack.stripHeight);
      final long = _msg(
        'l',
        _human,
        .3,
        text:
            'Your fleet burns tonight, little pilots, and every hatch we '
            'own opens on your heads!',
        duration: 4,
      );
      d.active.add(long);
      await pump(tester, d, .4);
      final a = tester.getRect(find.byKey(const ValueKey('comms-strip-s')));
      final b = tester.getRect(find.byKey(const ValueKey('comms-strip-l')));
      expect(a, alone, reason: 'the short toast neither moved nor grew');
      expect(b.height, CommsHudStack.stripHeight);
      expect(b.width, closeTo(a.width, .01));
      expect(b.right, lessThan(a.left));
      // The long line overflows its box and scrolls inside it.
      final box = tester.renderObject<RenderCommsScrollBox>(
        find.descendant(
          of: find.byKey(const ValueKey('comms-strip-l')),
          matching: find.byType(CommsScrollBox),
        ),
      );
      expect(box.overflow, greaterThan(0));
      final y0 = (box.child!.parentData! as BoxParentData).offset.dy;
      await pump(tester, d, long.endsAt - .3);
      final y1 = (box.child!.parentData! as BoxParentData).offset.dy;
      expect(y1, lessThan(y0));
      expect(
        tester.getRect(find.byKey(const ValueKey('comms-strip-l'))).height,
        CommsHudStack.stripHeight,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the comeback toast is the same height, full width', (
      tester,
    ) async {
      final d = CommsDirector();
      final opening = _msg('o', _human, 0, text: 'Ours!');
      final answer = _msg('r', _demon, 1.2, text: 'Not for long, pilot!')
        ..inReplyTo = opening;
      d.active.addAll([opening, answer]);
      await pump(tester, d, 1.5);
      final toast = find.byKey(const ValueKey('comms-conversation'));
      expect(tester.getSize(toast), const Size(360, CommsHudStack.stripHeight));
      expect(tester.takeException(), isNull);
    });
  });

  group('a busy channel', () {
    test('five minutes: no toast ever changes lane or comes back', () {
      final d = CommsDirector(random: math.Random(4), jitter: math.Random(5))
        ..setLineup(CommsLineup.pick(4))
        ..setSector(3, 0);
      final laneOf = <String, Set<CommsLane>>{};
      final closed = <CommsToast>{};
      final seen = <CommsToast>{};
      const events = [
        GameEventNames.weaponPickup,
        GameEventNames.broodChatter,
        GameEventNames.levelClear,
        GameEventNames.broodTaunt,
        GameEventNames.playerDestroyed,
      ];
      var pairs = 0;
      for (var i = 0; i < 300 * 30; i++) {
        final now = i / 30;
        if (i % 90 == 0) {
          d.handle(GameEvent(events[(i ~/ 90) % events.length]), now);
        }
        d.update(now, combat: true);
        d.lanes.sync(now, d.active, queue: d.queue);
        final shown = <CommsToast>{};
        for (final lane in CommsLane.values) {
          final t = d.lanes.toast(lane);
          if (t == null) continue;
          shown.add(t);
          expect(
            closed.contains(t),
            isFalse,
            reason: 'a closed toast came back',
          );
          if (t.pair) {
            expect(d.lanes.toast(CommsLane.human), same(t));
            expect(d.lanes.toast(CommsLane.demon), same(t));
            continue;
          }
          final m = t.messages.single;
          expect(CommsLanes.laneOf(m.character), lane);
          (laneOf['${m.line.id}@${m.startedAt}'] ??= {}).add(lane);
        }
        for (final t in seen.difference(shown)) {
          closed.add(t);
        }
        for (final t in shown) {
          if (t.pair && seen.add(t)) pairs++;
          seen.add(t);
        }
      }
      for (final e in laneOf.entries) {
        expect(e.value.length, 1, reason: e.key);
      }
      expect(seen.length, greaterThan(20));
      expect(pairs, greaterThan(0), reason: 'levelClear is an exchange');
    });
  });

  group('transition chatter selection', () {
    final longText = 'x' * (TransitionChatter.shortMax + 10);

    test('one long line stands alone', () {
      final c = TransitionChatter(openedAt: 0, lastStart: 5);
      final a = _msg('a', _human, .2, text: longText);
      final b = _msg('b', _demon, 3, text: 'Hah!');
      c.consider([a], .3);
      expect(c.shape, ChatterShape.long);
      expect(c.wantsSecond, isFalse);
      c.consider([a, b], 3.1);
      expect(c.shown, [a]);
    });

    test('two short lines, never a long second or a third', () {
      final c = TransitionChatter(openedAt: 0, lastStart: 5);
      final a = _msg('a', _human, .2, text: 'Clear skies!');
      c.consider([a], .3);
      expect(c.shape, ChatterShape.single);
      expect(c.wantsSecond, isTrue);
      final long = _msg('l', _demon, 2, text: longText);
      final b = _msg('b', _demon, 3, text: 'We will be back!');
      final third = _msg('t', _human, 4, text: 'Sure you will.');
      c.consider([a, long, b, third], 4.1);
      expect(c.shown, [a, b]);
      expect(c.shape, ChatterShape.twoShort);
      expect(c.hidden, {a, b});
    });

    test('a line and its comeback, whatever their length', () {
      final c = TransitionChatter(openedAt: 0, lastStart: 5);
      final opening = _msg('o', _human, .2, text: longText);
      final answer = _msg('r', _demon, 0, started: false, text: 'Hah!');
      opening.reply = answer;
      answer.inReplyTo = opening;
      c.consider([opening], .3);
      expect(c.shape, ChatterShape.comeback);
      expect(c.pendingReply, same(answer));
      expect(c.hidden, {opening, answer});
      final other = _msg('x', _demon, 1, text: 'Hah!');
      answer.startedAt = 1.6;
      c.consider([opening, other, answer], 1.7);
      expect(c.shown, [opening, answer]);
    });

    test('earlier exchanges and late lines stay on the dock', () {
      final c = TransitionChatter(openedAt: 1, lastStart: 5);
      final opening = _msg('o', _human, .5);
      final answer = _msg('r', _demon, 1.5)..inReplyTo = opening;
      final late = _msg('l', _human, 5.5);
      c.consider([opening, answer, late], 5.6);
      expect(c.shown, isEmpty);
      expect(c.shape, ChatterShape.none);
    });
  });

  group('transition chatter on the page', () {
    for (final size in const [Size(390, 844), Size(360, 640)]) {
      testWidgets('${size.width.round()}x${size.height.round()}: centred, '
          'clear of the ship, gone before play, never twice', (tester) async {
        final rig = await launch(tester, size);
        await rig.step(5);
        final m = rig.model;
        m.startAt(sector: 1, route: 0);
        await rig.step(6);
        rig.clearSector();
        var seen = false;
        for (var i = 0; i < 200 && m.flow.active; i++) {
          await rig.step(.1);
          final view = find.byKey(const ValueKey('transition-chatter'));
          if (view.evaluate().isEmpty) continue;
          seen = true;
          expect(
            m.flow.seconds,
            lessThanOrEqualTo(m.flow.plan.descentAt + .1),
            reason: 'gone before play resumes',
          );
          final r = tester.getRect(view);
          final arena = _arena(tester);
          final scale = math.min(
            arena.width / ArcadeModel.width,
            arena.height / ArcadeModel.height,
          );
          final shipTop =
              arena.bottom -
              ArcadeModel.height * scale +
              (ArcadeModel.shipY - m.flow.plan.climb - 26) * scale;
          expect(r.bottom, lessThanOrEqualTo(shipTop), reason: 'ship path');
          expect(r.top, greaterThanOrEqualTo(arena.top));
          expect((r.center.dx - arena.center.dx).abs(), lessThan(2));
          // Never blocks input.
          expect(
            find.ancestor(
              of: view,
              matching: find.byWidgetPredicate(
                (w) => w is IgnorePointer && w.ignoring,
              ),
            ),
            findsWidgets,
          );
          // A line shown over the clouds is never on the dock too.
          final chatter = rig.transitions.chatter as TransitionChatter?;
          expect(chatter, isNotNull);
          expect(chatter!.shown.length, lessThanOrEqualTo(2));
          for (final msg in chatter.shown) {
            expect(
              find.byKey(ValueKey('comms-strip-${msg.line.id}')),
              findsNothing,
            );
          }
        }
        expect(seen, isTrue, reason: '${rig.comms.director.history}');
        await dispose(tester);
      });
    }
  });
}

Rect _arena(WidgetTester tester) {
  final games = find.byWidgetPredicate((w) => w is GameWidget);
  final rects = [
    for (var i = 0; i < games.evaluate().length; i++)
      tester.getRect(games.at(i)),
  ]..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  return rects.first;
}
