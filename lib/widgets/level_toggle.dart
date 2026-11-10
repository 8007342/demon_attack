import 'package:flutter/material.dart';

/// A volume level of one audio channel (music or speech), cycled by
/// [LevelToggle]: Mute -> Low -> Full -> Mute. The audio engine keeps the
/// gains and remembers the choice per device (web/audio/demon-audio.js).
enum AudioLevel {
  mute,
  low,
  full;

  AudioLevel get next => AudioLevel.values[(index + 1) % 3];

  String get label => switch (this) {
    AudioLevel.mute => 'OFF',
    AudioLevel.low => 'LOW',
    AudioLevel.full => 'FULL',
  };

  String get spoken => switch (this) {
    AudioLevel.mute => 'muted',
    AudioLevel.low => 'low',
    AudioLevel.full => 'full',
  };

  static AudioLevel parse(String? value) => AudioLevel.values.firstWhere(
    (level) => level.name == value,
    orElse: () => AudioLevel.full,
  );
}

/// One small HUD toggle: the channel icon (struck through when muted), a
/// two-segment level meter and the level word. 38 logical pixels wide, so two
/// fit beside the pause button in the 360 px portrait HUD.
class LevelToggle extends StatelessWidget {
  const LevelToggle({
    super.key,
    required this.channel,
    required this.level,
    required this.icon,
    required this.mutedIcon,
    required this.onChanged,
  });

  /// 'Music' or 'Speech'.
  final String channel;
  final AudioLevel level;
  final IconData icon, mutedIcon;
  final ValueChanged<AudioLevel> onChanged;

  static const width = 38.0;
  static const _on = Color(0xFF7FE0C2), _dim = Color(0xFF34485C);
  static const _off = Color(0xFFFF8C89), _text = Color(0xFF95A9BB);

  @override
  Widget build(BuildContext context) {
    final muted = level == AudioLevel.mute;
    final lit = level.index; // 0, 1 or 2 segments
    return Semantics(
      button: true,
      label: '$channel volume ${level.spoken}',
      hint: 'Switches to ${level.next.spoken}',
      excludeSemantics: true,
      child: Tooltip(
        message: '$channel: ${level.label} (tap for ${level.next.label})',
        child: InkResponse(
          onTap: () => onChanged(level.next),
          radius: 22,
          child: SizedBox(
            width: width,
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  muted ? mutedIcon : icon,
                  size: 18,
                  color: muted ? _off : _text,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Container(
                        width: 8,
                        height: 3 + 2.0 * i,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: i < lit ? _on : _dim,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  level.label,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1,
                    letterSpacing: .5,
                    fontWeight: FontWeight.bold,
                    color: muted ? _off : (lit == 2 ? _on : _text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
