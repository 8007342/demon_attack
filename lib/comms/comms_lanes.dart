/// portrait-comms-lanes: the compact (portrait) radio dock as TWO
/// independent lanes. Humans (fleet and ground) on the left, the brood on
/// the right, as in the landscape call tiles. Each lane keeps its own FIFO
/// of waiting toasts, its own timeout and its own persistence: a toast,
/// once shown, stays in its lane until it expires and then closes in place.
/// It never slides to the other side and never resizes (the view gives
/// every toast one fixed size).
///
/// A linked exchange (a comeback: human → demon, demon → human, or any
/// line and its answer) is ONE combined toast across both lanes. It waits
/// for both lanes, and holds them while it waits: nothing new enters
/// either lane ahead of it. The pairing rule ([pairWait]): an occupant that
/// has been on screen for its reading time and is no longer speaking
/// closes at once (in place); any other occupant closes once the pair has
/// waited [pairWait] seconds. The director already lets an exchange start
/// only when the screen will be clear by the time its answer begins
/// (`_screenFree`), so the combined toast is up before the answer plays.
///
/// Pure Dart: driven by explicit timestamps, so tests are exact.
library;

import 'dart:math' as math;

import 'comms_director.dart';
import 'comms_types.dart';

/// The two portrait lanes, in screen order (left, right).
enum CommsLane { human, demon }

/// One toast on screen: a single line, or an exchange's two turns.
class CommsToast {
  CommsToast(this.messages, this.shownAt);

  /// One message, or the opening and its answer (the answer may not have
  /// started yet).
  final List<CommsMessage> messages;

  /// When the toast entered its lane(s).
  final double shownAt;

  /// Set when the toast was closed early to make room for an exchange.
  double? closedAt;

  bool get pair => messages.length == 2;

  /// The message drawn in [lane]'s half (a pair: humans on the left, the
  /// brood on the right; two of one side: the opening on the left).
  CommsMessage half(CommsLane lane) {
    if (!pair) return messages.single;
    final a = messages.first, b = messages.last;
    if (a.isDemon != b.isDemon) {
      return (lane == CommsLane.demon) == a.isDemon ? a : b;
    }
    return lane == CommsLane.human ? a : b;
  }

  /// When the toast closes: every started line has had its own hold and
  /// at least its reading time since the toast appeared; an answer still
  /// queued keeps the toast up (until the answer expires).
  double endsAt(double now, {Iterable<CommsMessage> queue = const []}) {
    var end = double.negativeInfinity;
    for (final m in messages) {
      if (m.started) {
        end = math.max(
          end,
          math.max(
            m.endsAt,
            math.max(shownAt, m.startedAt) + CommsMessage.readingTime(m.line),
          ),
        );
      } else if (now < m.expiresAt && queue.any((q) => identical(q, m))) {
        end = math.max(end, m.expiresAt);
      }
    }
    final closed = closedAt;
    return closed == null ? end : math.min(end, closed);
  }

  /// Opacity of a toast that fades in when it appears and out as it closes
  /// ([fade] seconds each way). Reduced motion: always 1.
  double opacity(
    double now, {
    Iterable<CommsMessage> queue = const [],
    bool reduce = false,
  }) => reduce
      ? 1.0
      : (math.min(now - shownAt, endsAt(now, queue: queue) - now) /
                CommsLanes.fade)
            .clamp(0.0, 1.0);
}

class _Waiting {
  _Waiting(this.messages, this.since);
  final List<CommsMessage> messages;
  final double since;
  bool get pair => messages.length == 2;
  CommsMessage get first => messages.first;
}

/// The two lanes of the portrait dock. [sync] is called with the
/// director's state each frame; [toast] reads what each lane shows.
class CommsLanes {
  /// Fade in and out of a toast, in seconds.
  static const fade = .18;

  /// Longest an exchange waits for an unread occupant of a lane before
  /// that occupant closes (in place) to make room.
  static const pairWait = 1.0;

  /// A line still waiting this long after its own end is dropped: it is
  /// stale, and the next one is more current.
  static const staleAfter = 2.0;

  /// At most this many single lines wait per lane; the oldest is dropped.
  static const maxWaiting = 2;

  final _shown = <CommsLane, CommsToast?>{};
  final _waiting = <_Waiting>[];
  final _seen = Set<CommsMessage>.identity();

  /// The lane a speaker's toasts use in portrait.
  static CommsLane laneOf(CommsCharacter who) =>
      who.isDemon ? CommsLane.demon : CommsLane.human;

  /// What [lane] shows (a pair toast is the same object in both lanes).
  CommsToast? toast(CommsLane lane) => _shown[lane];

  /// Lines waiting for [lane] (an exchange waiting counts in both).
  int waiting(CommsLane lane) =>
      _waiting.where((w) => w.pair || laneOf(w.first.character) == lane).length;

  /// An exchange is waiting for both lanes.
  bool get pairWaiting => _waiting.any((w) => w.pair);

  void clear() {
    _shown.clear();
    _waiting.clear();
    _seen.clear();
  }

  /// Advances the lanes to [now] from the director's [active] messages
  /// (and its [queue], for an answer not yet started). [hidden] messages
  /// are shown elsewhere (the urgent-mission card, the transition chatter)
  /// and stay out of the lanes.
  void sync(
    double now,
    Iterable<CommsMessage> active, {
    Iterable<CommsMessage> queue = const [],
    bool Function(CommsMessage)? hidden,
  }) {
    bool hide(CommsMessage m) => hidden?.call(m) ?? false;
    // 1. Retire toasts that expired (in place), or whose lines are now
    //    shown elsewhere.
    for (final lane in CommsLane.values) {
      final t = _shown[lane];
      if (t == null) continue;
      if (now >= t.endsAt(now, queue: queue) ||
          t.messages.where((m) => m.started).every(hide)) {
        _shown[lane] = null;
      }
    }
    // 2. Intake: every line that started, once, in start order.
    final fresh = [
      for (final m in active)
        if (m.started && !_seen.contains(m) && !hide(m)) m,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (final m in fresh) {
      _seen.add(m);
      if (now >= m.endsAt) continue; // already over
      final opening = m.inReplyTo;
      if (opening != null) {
        // The answer of an exchange already on screen or waiting fills its
        // half of the combined toast.
        final known =
            _shown.values.any((t) => t != null && t.messages.contains(m)) ||
            _waiting.any((w) => w.messages.contains(m));
        if (known) continue;
        if (!hide(opening)) {
          _waiting.add(_Waiting([opening, m], now));
          continue;
        }
      }
      final reply =
          m.reply ?? active.where((a) => identical(a.inReplyTo, m)).firstOrNull;
      if (reply != null && !hide(reply)) {
        _waiting.add(_Waiting([m, reply], now));
      } else {
        _waiting.add(_Waiting([m], now));
      }
    }
    // 3. Drop stale waiting lines.
    _waiting.removeWhere(
      (w) => w.messages.every(
        (m) => m.started ? now > m.endsAt + staleAfter : now >= m.expiresAt,
      ),
    );
    // 4. Place, oldest first. A lane is FIFO: once something waits for it,
    //    nothing later jumps ahead. A waiting exchange reserves both.
    final blocked = <CommsLane>{};
    for (final w in [..._waiting]) {
      if (!w.pair) {
        final lane = laneOf(w.first.character);
        if (!blocked.contains(lane) && _shown[lane] == null) {
          _shown[lane] = CommsToast(w.messages, now);
          _waiting.remove(w);
        } else {
          blocked.add(lane);
        }
        continue;
      }
      final free =
          blocked.isEmpty && CommsLane.values.every((l) => _shown[l] == null);
      if (free) {
        final t = CommsToast(w.messages, now);
        for (final l in CommsLane.values) {
          _shown[l] = t;
        }
        _waiting.remove(w);
        continue;
      }
      // The pairing rule: read occupants close now, unread ones after
      // [pairWait]; always in place, with the usual fade.
      final waited = now - w.since >= pairWait;
      for (final l in CommsLane.values) {
        final t = _shown[l];
        if (t == null || t.pair || t.closedAt != null) continue;
        final m = t.messages.single;
        final read =
            now - t.shownAt >= CommsMessage.readingTime(m.line) &&
            !m.speaking(now);
        if (read || waited) t.closedAt = now + fade;
      }
      blocked.addAll(CommsLane.values);
    }
    // 5. At most [maxWaiting] single lines wait per lane: the oldest go.
    for (final lane in CommsLane.values) {
      final singles = [
        for (final w in _waiting)
          if (!w.pair && laneOf(w.first.character) == lane) w,
      ];
      for (var i = 0; i < singles.length - maxWaiting; i++) {
        _waiting.remove(singles[i]);
      }
    }
  }
}
