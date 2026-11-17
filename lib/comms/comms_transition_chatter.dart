/// portrait-comms-lanes: the radio chatter of a level transition, shown at
/// the landscape tiles' full size in the middle of the arena, over the
/// clouds of the Pursuit. One long line, OR two short ones, OR one line
/// with its comeback (an exchange's answer from the other side).
///
/// Picked by length, from the lines that start on the channel while the
/// transition's message slot is open. Lines it does not take stay on the
/// portrait dock's lanes; a line it takes never shows on the dock.
///
/// Pure Dart: driven by explicit timestamps, so tests are exact.
library;

import 'comms_director.dart';

/// What the chatter holds.
enum ChatterShape { none, single, long, twoShort, comeback }

class TransitionChatter {
  TransitionChatter({required this.openedAt, required this.lastStart});

  /// A line of at most this many characters (its text, or a grunt's SIGINT
  /// gloss) is short: two fit side by side at the tiles' size on a 360-px
  /// phone (about 19 characters a line, three lines each). Longer lines
  /// take the whole width alone.
  static const shortMax = 48;

  /// When the slot opened (comms clock): earlier lines belong to the dock.
  final double openedAt;

  /// The latest a line may start and still join (comms clock): later
  /// lines could not be read before the Descent.
  final double lastStart;

  /// The lines shown, in start order (an exchange: opening, then answer).
  final List<CommsMessage> shown = [];
  final _passed = Set<CommsMessage>.identity();

  static String textOf(CommsMessage m) =>
      m.line.isGrunt ? (m.line.gloss ?? '') : (m.line.text ?? '');

  static bool isShort(CommsMessage m) => textOf(m).length <= shortMax;

  static bool linked(CommsMessage m) => m.reply != null || m.inReplyTo != null;

  ChatterShape get shape {
    if (shown.isEmpty) return ChatterShape.none;
    final first = shown.first;
    if (first.reply != null) return ChatterShape.comeback;
    if (shown.length == 2) return ChatterShape.twoShort;
    return isShort(first) ? ChatterShape.single : ChatterShape.long;
  }

  /// The comeback's answer, before it starts (drawn waiting).
  CommsMessage? get pendingReply {
    final reply = shown.isEmpty ? null : shown.first.reply;
    return reply != null && !shown.contains(reply) ? reply : null;
  }

  /// One short line alone, unlinked: a second short line may join it.
  bool get wantsSecond =>
      shown.length == 1 && !linked(shown.single) && isShort(shown.single);

  /// Every line the chatter shows (for the dock to leave out), including
  /// a comeback's answer before it starts.
  Set<CommsMessage> get hidden => {...shown, ?pendingReply};

  /// Considers the lines that started on the channel: takes the ones the
  /// rules allow, in start order, once each. Returns true when it took one.
  bool consider(Iterable<CommsMessage> active, double now) {
    final fresh = [
      for (final m in active)
        if (m.started &&
            !shown.contains(m) &&
            !_passed.contains(m) &&
            m.startedAt >= openedAt - 1e-9)
          m,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    var took = false;
    for (final m in fresh) {
      if (_accepts(m)) {
        shown.add(m);
        took = true;
      } else {
        _passed.add(m);
      }
    }
    return took;
  }

  bool _accepts(CommsMessage m) {
    if (shown.isEmpty) {
      // The answer of an exchange that opened before the slot stays with
      // its opening on the dock; a line too late to be read stays there too.
      return m.inReplyTo == null && m.startedAt <= lastStart + 1e-9;
    }
    if (shown.length >= 2) return false;
    final first = shown.single;
    if (identical(first.reply, m)) return true; // the comeback
    // The first card holds its half until the chatter closes, so a second
    // short line may join it any time before the last start.
    return wantsSecond &&
        !linked(m) &&
        isShort(m) &&
        m.startedAt <= lastStart + 1e-9;
  }
}
