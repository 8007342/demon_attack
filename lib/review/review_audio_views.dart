/// Audio viewers of the review studio: one radio clip with its portrait,
/// lip-sync and subtitle (the game's own CommsMouth, paintPortrait and
/// CommsSubtitle), and one music cue with loopable sections.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../comms/comms_director.dart';
import '../comms/comms_mouth.dart';
import '../comms/comms_types.dart';
import '../comms/comms_view.dart';
import 'notes_panel.dart';
import 'review_catalog.dart';
import 'review_platform.dart';

/// Polls a [ReviewAudio] playhead every frame while mounted.
mixin _Playhead<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _ticker = createTicker((_) => onTick());
  void onTick();

  void startPolling() => _ticker.start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class RadioView extends StatefulWidget {
  const RadioView({
    super.key,
    required this.clip,
    required this.audio,
    required this.link,
    this.onNext,
    this.onPrevious,
  });
  final RadioClip clip;
  final ReviewAudio audio;
  final PlayheadLink link;
  final VoidCallback? onNext, onPrevious;
  @override
  State<RadioView> createState() => _RadioViewState();
}

class _RadioViewState extends State<RadioView>
    with SingleTickerProviderStateMixin, _Playhead {
  double position = 0;
  bool playing = false, started = false;
  static bool autoNext = false;

  RadioClip get clip => widget.clip;

  @override
  void initState() {
    super.initState();
    _bind();
    startPolling();
    if (autoNext) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _bind() {
    widget.link
      ..position = (() => position)
      ..section = (() => clip.event)
      ..seek = (s) {
        if (!started) _play();
        widget.audio.seek(s);
      };
  }

  @override
  void didUpdateWidget(RadioView old) {
    super.didUpdateWidget(old);
    _bind();
    if (old.clip != clip) {
      widget.audio.pause();
      position = 0;
      started = false;
      if (autoNext && playing) {
        _play();
      } else {
        playing = false;
      }
    }
  }

  @override
  void dispose() {
    widget.audio.pause();
    super.dispose();
  }

  void _play() {
    widget.audio.play(clip.url);
    setState(() {
      started = true;
      playing = true;
    });
  }

  @override
  void onTick() {
    if (!started) return;
    final p = widget.audio.position, now = widget.audio.playing;
    final ended = playing && !now && p >= clip.line.duration - .05;
    if (p != position || now != playing) {
      setState(() {
        position = p;
        playing = now;
      });
    }
    if (ended && autoNext && widget.onNext != null) widget.onNext!();
  }

  @override
  Widget build(BuildContext context) {
    final line = clip.line, who = clip.character;
    final message = CommsMessage(
      trigger: clip.trigger,
      line: line,
      character: who,
      priority: clip.trigger.priority,
      queuedAt: 0,
      readyAt: 0,
      expiresAt: 1e9,
      sequence: 0,
    )..startedAt = 0;
    final t = started ? position : line.duration;
    final meta = clip.meta;
    String m(String key, [int digits = 2]) => switch (meta[key]) {
      final num v => v.toStringAsFixed(digits),
      final String v => v,
      _ => '—',
    };
    return CommsAtlasScope(
      child: LayoutBuilder(
        builder: (context, box) {
          final side = math.min(
            256.0,
            math.min(box.maxWidth - 32, box.maxHeight * .5),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: SizedBox(
                  width: side * 1.25,
                  height: side,
                  child: CustomPaint(
                    painter: _ClipPortrait(
                      clip,
                      started && playing ? position : -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                color: studioPanel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who.isDemon
                          ? '${who.rank} ${who.name}'
                          : '${who.rank} ${who.name} · ${who.callsign}',
                      style: TextStyle(
                        color: Color(who.accent),
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CommsSubtitle(
                      message: message,
                      now: t,
                      fontSize: 15,
                      maxLines: 4,
                      glyphHeight: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous clip',
                    onPressed: widget.onPrevious,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    key: const ValueKey('radio-play'),
                    tooltip: 'Play / pause',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (!started ||
                          (!playing && position >= line.duration - .05)) {
                        _play();
                      } else if (playing) {
                        widget.audio.pause();
                      } else {
                        widget.audio.resume();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Next clip',
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.skip_next),
                  ),
                  Expanded(
                    child: Slider(
                      value: position.clamp(0, line.duration),
                      max: line.duration,
                      onChanged: (v) {
                        if (!started) _play();
                        widget.audio.seek(v);
                        setState(() => position = v);
                      },
                    ),
                  ),
                  Text(
                    '${position.toStringAsFixed(2)} / ${line.duration.toStringAsFixed(2)} s',
                    style: const TextStyle(color: studioDim, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: autoNext,
                    onChanged: (v) => setState(() => autoNext = v ?? false),
                  ),
                  const Text(
                    'auto-play the next clip in the list',
                    style: TextStyle(color: studioDim, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (final (k, v) in [
                    ('clip', line.id),
                    ('event', clip.trigger.name),
                    ('side', who.side.name),
                    ('emotion', clip.emotion.isEmpty ? '—' : clip.emotion),
                    ('engine', m('engine')),
                    ('LUFS', m('lufs')),
                    ('decoded LUFS', m('decoded_lufs')),
                    ('peak dBFS', m('decoded_peak_dbfs')),
                    ('duration', '${line.duration.toStringAsFixed(2)} s'),
                    (
                      'priority',
                      '${clip.trigger.priority}${clip.trigger.urgent ? ' urgent' : ''}',
                    ),
                    ('signature', line.signature ? 'yes' : 'no'),
                    ('ogg bytes', m('ogg_bytes', 0)),
                  ])
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$k ',
                            style: const TextStyle(color: studioDim),
                          ),
                          TextSpan(
                            text: v,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Backdrop, portrait and lip-sync at clip time [t] (negative: resting).
class _ClipPortrait extends CustomPainter {
  _ClipPortrait(this.clip, this.t);
  final RadioClip clip;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintBackdrop(canvas, rect, clip.character, 0, reduceMotion: true);
    final side = size.height;
    final dst = Rect.fromCenter(center: rect.center, width: side, height: side);
    if (t < 0) {
      paintPortrait(
        canvas,
        dst,
        clip.character.id,
        CommsFrame.idle,
        accent: Color(clip.character.accent),
      );
      return;
    }
    final (from, to, amount) = CommsMouth.of(clip.line).blendAt(t);
    paintPortrait(
      canvas,
      dst,
      clip.character.id,
      to,
      accent: Color(clip.character.accent),
      from: from,
      amount: amount,
    );
  }

  @override
  bool shouldRepaint(_ClipPortrait old) => old.t != t || old.clip != clip;
}

/// The loop choices of a music cue.
enum MusicLoop { off, whole, seam, bars, slot }

class MusicView extends StatefulWidget {
  const MusicView({
    super.key,
    required this.cue,
    required this.audio,
    required this.link,
  });
  final MusicCue cue;
  final ReviewAudio audio;
  final PlayheadLink link;
  @override
  State<MusicView> createState() => _MusicViewState();
}

class _MusicViewState extends State<MusicView>
    with SingleTickerProviderStateMixin, _Playhead {
  double position = 0;
  bool playing = false, started = false;
  MusicLoop loop = MusicLoop.whole;
  RangeValues bars = const RangeValues(0, 1);
  int slot = 0;

  MusicCue get cue => widget.cue;
  int get barCount => math.max(1, (cue.seconds / cue.barSeconds).round());

  @override
  void initState() {
    super.initState();
    _reset();
    _bind();
    startPolling();
  }

  void _reset() {
    position = 0;
    started = false;
    playing = false;
    bars = RangeValues(0, math.min(2, barCount).toDouble());
    slot = 0;
    loop = cue.slots.isNotEmpty
        ? MusicLoop.slot
        : cue.kind == 'loop'
        ? MusicLoop.whole
        : MusicLoop.off;
  }

  void _bind() {
    widget.link
      ..position = (() => position)
      ..section = (() => _sectionLabel(position))
      ..seek = _seek;
  }

  @override
  void didUpdateWidget(MusicView old) {
    super.didUpdateWidget(old);
    _bind();
    if (old.cue != cue) {
      widget.audio.pause();
      _reset();
    }
  }

  @override
  void dispose() {
    widget.audio.pause();
    super.dispose();
  }

  /// The looped region, or null.
  (double, double)? get region => switch (loop) {
    MusicLoop.off => null,
    MusicLoop.whole => (0, cue.seconds),
    MusicLoop.seam when cue.loopStart != null && cue.loopEnd != null => (
      cue.loopStart!,
      cue.loopEnd!,
    ),
    MusicLoop.seam => null,
    MusicLoop.bars => (bars.start * cue.barSeconds, bars.end * cue.barSeconds),
    MusicLoop.slot when cue.slots.isNotEmpty => (
      slot * cue.slotSeconds,
      (slot + 1) * cue.slotSeconds,
    ),
    MusicLoop.slot => null,
  };

  String _sectionLabel(double t) {
    final bar = (t / cue.barSeconds).floor() + 1;
    return switch (loop) {
      MusicLoop.slot when cue.slots.isNotEmpty => 'slot ${cue.slots[slot]}',
      MusicLoop.bars =>
        'bars ${bars.start.round() + 1}-${bars.end.round()} (bar $bar)',
      MusicLoop.seam => 'loop seam (bar $bar)',
      _ => 'bar $bar',
    };
  }

  void _seek(double s) {
    if (!started) _play(from: s);
    widget.audio.seek(s);
    setState(() => position = s);
  }

  void _play({double? from}) {
    widget.audio.play(cue.url);
    final start = from ?? region?.$1 ?? 0;
    if (start > 0) widget.audio.seek(start);
    setState(() {
      started = true;
      playing = true;
      position = start;
    });
  }

  @override
  void onTick() {
    if (!started) return;
    var p = widget.audio.position;
    final r = region;
    if (r != null &&
        widget.audio.playing &&
        (p >= r.$2 - .015 || p < r.$1 - .25)) {
      widget.audio.seek(r.$1);
      p = r.$1;
    } else if (r != null &&
        !widget.audio.playing &&
        playing &&
        p >= cue.seconds - .05) {
      // The element ended before the loop point (a loop to the very end).
      widget.audio.seek(r.$1);
      widget.audio.resume();
      p = r.$1;
    }
    final now = widget.audio.playing || (r != null && playing);
    if (p != position || now != playing) {
      setState(() {
        position = p;
        playing = now;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = region;
    final meta = cue.meta;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          cue.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${cue.kind} · ${cue.seconds.toStringAsFixed(2)} s · ${cue.bpm.toStringAsFixed(1)} BPM · '
          '$barCount bars of ${cue.barSeconds.toStringAsFixed(3)} s'
          '${meta['keyscale'] != null ? ' · ${meta['keyscale']}' : ''}',
          style: const TextStyle(color: studioDim, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              key: const ValueKey('music-timeline'),
              onTapDown: (d) => _seek(
                (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0) *
                    cue.seconds,
              ),
              child: CustomPaint(
                size: Size(box.maxWidth, 56),
                painter: _Timeline(cue, position, r),
              ),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              key: const ValueKey('music-play'),
              tooltip: 'Play / pause',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (!started) {
                  _play();
                } else if (playing) {
                  widget.audio.pause();
                  setState(() => playing = false);
                } else {
                  if (position >= cue.seconds - .05) {
                    widget.audio.seek(r?.$1 ?? 0);
                  }
                  widget.audio.resume();
                  setState(() => playing = true);
                }
              },
            ),
            IconButton(
              tooltip: 'Restart the section',
              icon: const Icon(Icons.replay),
              onPressed: () => started ? _seek(r?.$1 ?? 0) : _play(),
            ),
            Text(
              '${clockLabel(position)} · ${_sectionLabel(position)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'LOOP',
              style: TextStyle(color: studioDim, fontSize: 11),
            ),
            for (final mode in MusicLoop.values)
              if (switch (mode) {
                MusicLoop.seam => cue.loopStart != null && cue.loopEnd != null,
                MusicLoop.slot => cue.slots.isNotEmpty,
                _ => true,
              })
                ChoiceChip(
                  key: ValueKey('loop-${mode.name}'),
                  label: Text(switch (mode) {
                    MusicLoop.off => 'off',
                    MusicLoop.whole => 'whole cue',
                    MusicLoop.seam =>
                      'seam ${cue.loopStart!.toStringAsFixed(2)}–${cue.loopEnd!.toStringAsFixed(2)} s',
                    MusicLoop.bars => 'bars',
                    MusicLoop.slot => 'slot',
                  }),
                  selected: loop == mode,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => loop = mode),
                ),
          ],
        ),
        if (loop == MusicLoop.bars)
          Row(
            children: [
              Expanded(
                child: RangeSlider(
                  values: bars,
                  max: barCount.toDouble(),
                  divisions: barCount,
                  labels: RangeLabels(
                    '${bars.start.round() + 1}',
                    '${bars.end.round()}',
                  ),
                  onChanged: (v) => setState(() {
                    if (v.end - v.start >= 1) bars = v;
                  }),
                ),
              ),
              Text(
                'bars ${bars.start.round() + 1}–${bars.end.round()}',
                style: const TextStyle(color: studioDim, fontSize: 11),
              ),
            ],
          ),
        if (loop == MusicLoop.slot && cue.slots.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < cue.slots.length; i++)
                ChoiceChip(
                  label: Text(cue.slots[i]),
                  selected: slot == i,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() => slot = i);
                    started ? _seek(i * cue.slotSeconds) : _play();
                  },
                ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final MapEntry(:key, :value) in meta.entries)
              if (value is num || value is String || value is bool)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$key ',
                        style: const TextStyle(color: studioDim),
                      ),
                      TextSpan(
                        text: value is double
                            ? value.toStringAsFixed(3)
                            : '$value',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
            if (cue.score != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'score ',
                      style: TextStyle(color: studioDim),
                    ),
                    TextSpan(
                      text: cue.score,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

/// Bars, beat ticks, the loop region, slot names and the playhead.
class _Timeline extends CustomPainter {
  _Timeline(this.cue, this.position, this.region);
  final MusicCue cue;
  final double position;
  final (double, double)? region;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (cue.seconds <= 0) return;
    double x(double t) => t / cue.seconds * w;
    canvas.drawRect(Offset.zero & size, Paint()..color = studioPanel);
    final r = region;
    if (r != null) {
      canvas.drawRect(
        Rect.fromLTRB(x(r.$1), 0, x(r.$2), h),
        Paint()..color = studioMint.withValues(alpha: .18),
      );
    }
    final bar = Paint()..color = studioLine;
    for (var t = 0.0; t < cue.seconds; t += cue.barSeconds) {
      canvas.drawRect(Rect.fromLTWH(x(t), 0, 1, h), bar);
    }
    if (cue.slots.isNotEmpty) {
      for (var i = 0; i < cue.slots.length; i++) {
        final tp = TextPainter(
          text: TextSpan(
            text: cue.slots[i],
            style: const TextStyle(color: studioDim, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x(i * cue.slotSeconds) + 3, 3));
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(x(position.clamp(0, cue.seconds)) - 1, 0, 2, h),
      Paint()..color = studioGold,
    );
  }

  @override
  bool shouldRepaint(_Timeline old) =>
      old.position != position || old.region != region || old.cue != cue;
}
