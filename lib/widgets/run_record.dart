// bonus-balance: the end-of-run medal screen's run record. One compact
// card: the medals earned (of five), the score, the play time, the play
// date and the run's modifiers (the bonus levels met, the run rule). Sized
// for a 360-wide phone: two short rows and a row of mission medals.
// mission-medals: the modifiers are badges (mission_medal.dart), never
// text chips; a mission's name is its medal's label and tap tooltip.
import 'package:flutter/material.dart';

import '../services/scores.dart';
import 'medal.dart';
import 'mission_medal.dart';

const _mint = Color(0xFF70F5D5);
const _gold = Color(0xFFF4CA79);
const _muted = Color(0xFF8AA1B8);

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// `2026-11-16` as `16 NOV 2026`; null or malformed: null.
String? playDateLabel(String? day) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day ?? '');
  if (m == null) return null;
  final month = int.parse(m[2]!);
  if (month < 1 || month > 12) return null;
  return '${int.parse(m[3]!)} ${_months[month - 1]} ${m[1]}';
}

/// `mm:ss` (hours fold into the minutes); null: a dash.
String playTimeLabel(int? milliseconds) {
  if (milliseconds == null) return '—';
  final seconds = milliseconds ~/ 1000;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

class RunRecordCard extends StatelessWidget {
  const RunRecordCard({super.key, required this.entry});
  final ScoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = playDateLabel(entry.playedOn);
    final missions = entry.modifiers;
    TextStyle small(Color c) =>
        TextStyle(fontSize: 9, letterSpacing: 1.2, color: c, height: 1.3);
    return Container(
      key: const ValueKey('run-record'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xC9081220),
        border: Border.all(color: const Color(0xFF2B4254)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Medal(
                  difficulty: entry.difficulty,
                  ordinal: i,
                  earned: i < entry.medals,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                key: const ValueKey('run-record-medals'),
                '${entry.medals}/5 MEDALS',
                style: small(_gold),
              ),
              const Spacer(),
              Text(entry.difficulty.name.toUpperCase(), style: small(_muted)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                key: const ValueKey('run-record-score'),
                entry.score.toString().padLeft(6, '0'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _mint,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key: const ValueKey('run-record-time'),
                    'TIME ${playTimeLabel(entry.activeMilliseconds)}',
                    style: small(Colors.white),
                  ),
                  if (date != null)
                    Text(
                      key: const ValueKey('run-record-date'),
                      date,
                      style: small(_muted),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (missions.isEmpty)
            Text(
              key: const ValueKey('run-record-standard'),
              'STANDARD RUN',
              style: small(const Color(0xFF647D94)),
            )
          else
            // --- mission-medals: one medal per mission met.
            Wrap(
              key: const ValueKey('run-record-modifiers'),
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in missions) MissionMedal(id: id, size: 34),
              ],
            ),
        ],
      ),
    );
  }
}
