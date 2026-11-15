// ux-declutter: no progress bar, strip, timer bar or meter in the game UI.
//
// Review frames: flutter test test/ux_declutter_test.dart
//   --dart-define=FLUID_RENDER=/abs/dir --dart-define=FLUID_FONTS=/abs/fonts
// writes ux-<moment>-<w>x<h>.png for each moment and size (see
// openspec/changes/ux-declutter/design.md §Review frames).
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/widgets/power_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show dispose, launch, snap;

/// Nothing that reads as a progress bar is on screen.
void expectNoBars() {
  expect(find.byType(LinearProgressIndicator), findsNothing);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.byKey(const ValueKey('transition-strip')), findsNothing);
  expect(find.byKey(const ValueKey('power-homing')), findsNothing);
  expect(
    find.descendant(of: find.byType(PowerStatus), matching: find.byType(Text)),
    findsNothing,
  );
}

void main() {
  for (final size in const [Size(360, 780), Size(1280, 720)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    group('no progress bars at $tag', () {
      testWidgets('opening tip and combat with powers', (tester) async {
        final rig = await launch(tester, size);
        await snap(tester, 'ux-opening-$tag');
        expectNoBars();
        await rig.step(5);
        rig.model
          ..invulnerable = 0
          ..powerTimers.addAll({
            Power.spread: 9,
            Power.rapid: 7,
            Power.shield: 2.4, // blinking off this frame
          });
        await rig.step(1 / 30);
        await snap(tester, 'ux-combat-powers-$tag');
        expectNoBars();
        expect(find.byKey(const ValueKey('combined-power-glyph')), findsOne);
        await dispose(tester);
      });

      testWidgets('wave change', (tester) async {
        final rig = await launch(tester, size);
        await rig.step(5);
        rig.model.wave = 2;
        rig.model.mode = RunMode.transition;
        rig.model.transitionDuration = 1.4 + ArcadeModel.storyReadingTime;
        rig.model.transitionLeft = rig.model.transitionDuration;
        await rig.step(.5);
        await snap(tester, 'ux-wave-change-$tag');
        expectNoBars();
        expect(rig.primaries(), 0);
        await dispose(tester);
      });

      testWidgets('sector clear, salvage and travel', (tester) async {
        final rig = await launch(tester, size);
        await rig.step(5);
        rig.clearSector();
        final shots = <RunMode>{};
        var frames = 0;
        while (rig.model.mode != RunMode.playing && frames < 600) {
          await rig.step(1 / 10);
          frames++;
          final mode = rig.model.presentationMode;
          if (rig.model.transitionProgress > .4 && shots.add(mode)) {
            await snap(tester, 'ux-${mode.name}-$tag');
          }
          expectNoBars();
        }
        expect(shots, contains(RunMode.travel));
        await dispose(tester);
      });

      testWidgets('carrier arrival alert', (tester) async {
        final rig = await launch(tester, size);
        await rig.step(5);
        rig.model.startAt(sector: 5);
        await rig.step(1.5);
        expect(rig.model.isBoss, isTrue);
        await snap(tester, 'ux-carrier-alert-$tag');
        expectNoBars();
        await dispose(tester);
      });
    });
  }
}
