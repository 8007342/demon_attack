/// carrier-hatches §A12: radio lines that must fit one line at the dock's
/// larger subtitle size. Their text is at most [commsOneLineMax]
/// characters (`test/comms_line_length_test.dart` checks `lines.json`) and
/// the dock draws them with `maxLines: 1` at full width.
const commsOneLineTriggers = {
  'bossHintHatches',
  'bossHintTiming',
  'bossHintLead',
};

/// The one-line limit at 14.5 px on a 360-px phone (about 8.7 px per
/// monospace glyph in a 245-px text column).
const commsOneLineMax = 28;

/// The dock's subtitle size on phones (was 13) and its speaker tag (was
/// 9.5); the desktop tiles' base size (unchanged: 14.5 overflowed the brood glyph column).
const commsStripFont = 14.5, commsStripTagFont = 10.5, commsTileFont = 13.5;

/// Whether line [id] (`<trigger>.h<n>` / `.d<n>`) is a one-line line.
bool commsOneLine(String id) {
  final dot = id.lastIndexOf('.');
  return commsOneLineTriggers.contains(dot < 0 ? id : id.substring(0, dot));
}
