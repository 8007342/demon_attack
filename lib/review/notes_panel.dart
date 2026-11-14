import 'package:flutter/material.dart';

import 'review_notes.dart';

/// How a viewer shares its playhead with the notes panel: the time to stamp
/// on a note, the section in view (route, loop range, frame), and a seek for
/// jumping back to a note's offset.
class PlayheadLink {
  double? Function()? position;
  String? Function()? section;
  void Function(double seconds)? seek;

  void clear() {
    position = null;
    section = null;
    seek = null;
  }
}

const studioInk = Color(0xFF0B0A1C);
const studioPanel = Color(0xFF121A2A);
const studioLine = Color(0xFF2B4254);
const studioMint = Color(0xFF70F5D5);
const studioGold = Color(0xFFEFBD57);
const studioDim = Color(0xFF8D9EB3);
const studioCoral = Color(0xFFFF786C);

String clockLabel(double seconds) {
  final m = seconds ~/ 60;
  final s = seconds - m * 60;
  return '$m:${s.toStringAsFixed(2).padLeft(5, '0')}';
}

Color tagColor(String tag) => switch (tag) {
  'keep' => studioMint,
  'regenerate' => studioCoral,
  'refine' => studioGold,
  _ => const Color(0xFFA888FF),
};

/// Quick tags, a free-text note and the playhead time for one asset, above
/// the notes already written on it.
class NotesPanel extends StatefulWidget {
  const NotesPanel({
    super.key,
    required this.asset,
    required this.store,
    required this.link,
  });
  final ReviewAsset asset;
  final ReviewNotesStore store;
  final PlayheadLink link;

  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  final _text = TextEditingController();
  final _tags = <String>{};
  bool _attachTime = true;
  double? _offset;
  String? _section;
  String? _editing;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void didUpdateWidget(NotesPanel old) {
    super.didUpdateWidget(old);
    if (old.asset.ref != widget.asset.ref) {
      _reset();
      _restoreDraft();
    }
  }

  /// Unsaved text and tags survive a reload (browser storage).
  void _restoreDraft() {
    final d = widget.store.draft(widget.asset.ref);
    if (d == null) return;
    _text.text = d.text;
    _tags.addAll(d.tags);
  }

  void _keepDraft() {
    if (_editing != null) return;
    widget.store.saveDraft(widget.asset.ref, _text.text, _tags);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _reset() {
    _text.clear();
    _tags.clear();
    _offset = null;
    _section = null;
    _editing = null;
  }

  /// The playhead is captured when writing starts, so a note keeps the
  /// moment the operator heard or saw the problem.
  void _mark({bool force = false}) {
    if (_editing != null) return;
    if (_offset == null || force) {
      _offset = widget.link.position?.call();
      _section = widget.link.section?.call();
    }
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty && _tags.isEmpty) return;
    final editing = _editing;
    if (editing != null) {
      widget.store.edit(editing, tags: _tags.toList(), text: text);
    } else {
      _mark();
      widget.store.add(
        widget.asset,
        tags: [
          for (final t in reviewTags)
            if (_tags.contains(t.id)) t.id,
        ],
        text: text,
        offset: _attachTime ? _offset : null,
        section: _section,
      );
      widget.store.saveDraft(widget.asset.ref, '', const []);
    }
    setState(_reset);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final hash = asset.hash;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final notes = widget.store.notesFor(asset.ref);
        final canSave = _tags.isNotEmpty || _text.text.trim().isNotEmpty;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              asset.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              '${asset.ref}\n${asset.source}\n'
              '${hash == null ? 'hash: (computing or unknown)' : 'sha256 ${hash.substring(0, 16)}'}'
              '${buildCommit.isEmpty ? '' : ' · build $buildCommit'}',
              style: const TextStyle(
                color: studioDim,
                fontSize: 10,
                height: 1.4,
              ),
            ),
            const Divider(color: studioLine, height: 20),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in reviewTags)
                  if (tag.offeredFor(asset.kind))
                    FilterChip(
                      key: ValueKey('tag-${tag.id}'),
                      label: Text(
                        tag.label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _tags.contains(tag.id),
                      visualDensity: VisualDensity.compact,
                      selectedColor: tagColor(tag.id).withValues(alpha: .35),
                      onSelected: (on) => setState(() {
                        _mark();
                        on ? _tags.add(tag.id) : _tags.remove(tag.id);
                        _keepDraft();
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('note-text'),
              controller: _text,
              minLines: 2,
              maxLines: 6,
              maxLength: 4000,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: asset.kind == ReviewKind.page
                    ? 'What did you notice? e.g. "sector 3 dives feel '
                          'too fast", "music cuts out after the boss"'
                    : 'What is wrong, and where? e.g. "no growl on the '
                          'second roar", "flat delivery"',
                hintStyle: const TextStyle(color: studioDim, fontSize: 12),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                setState(_mark);
                _keepDraft();
              },
            ),
            Row(
              children: [
                if (_editing == null) ...[
                  Checkbox(
                    value: _attachTime,
                    onChanged: (v) => setState(() => _attachTime = v ?? true),
                  ),
                  Expanded(
                    child: Text(
                      _offset != null
                          ? '@ ${clockLabel(_offset!)}'
                                '${_section == null ? '' : ' · $_section'}'
                          : 'attach playhead time',
                      style: const TextStyle(color: studioDim, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Re-mark at the current playhead',
                    icon: const Icon(Icons.my_location, size: 18),
                    color: studioDim,
                    onPressed: () => setState(() => _mark(force: true)),
                  ),
                ] else
                  const Expanded(
                    child: Text(
                      'Editing a note (tags and text)',
                      style: TextStyle(color: studioGold, fontSize: 11),
                    ),
                  ),
                if (_editing != null)
                  TextButton(
                    onPressed: () => setState(_reset),
                    child: const Text('Cancel'),
                  ),
                FilledButton(
                  key: const ValueKey('note-save'),
                  onPressed: canSave ? _save : null,
                  child: Text(_editing == null ? 'Add note' : 'Save'),
                ),
              ],
            ),
            const Divider(color: studioLine, height: 24),
            Text(
              notes.isEmpty
                  ? 'No notes on this asset yet.'
                  : '${notes.length} notes',
              style: const TextStyle(color: studioDim, fontSize: 11),
            ),
            for (final n in notes) _noteTile(n),
          ],
        );
      },
    );
  }

  Widget _noteTile(ReviewNote n) {
    final seek = widget.link.seek;
    return Container(
      key: ValueKey('note-${n.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: studioLine),
        color: studioInk,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in n.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        color: tagColor(t).withValues(alpha: .25),
                        child: Text(
                          t,
                          style: TextStyle(color: tagColor(t), fontSize: 10),
                        ),
                      ),
                    if (n.offset != null)
                      InkWell(
                        onTap: seek == null ? null : () => seek(n.offset!),
                        child: Text(
                          '@ ${clockLabel(n.offset!)}',
                          style: TextStyle(
                            color: seek == null ? studioDim : studioMint,
                            fontSize: 10,
                            decoration: seek == null
                                ? null
                                : TextDecoration.underline,
                          ),
                        ),
                      ),
                    if (n.section != null)
                      Text(
                        n.section!,
                        style: const TextStyle(color: studioDim, fontSize: 10),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, size: 16),
                color: studioDim,
                onPressed: () => setState(() {
                  _editing = n.id;
                  _tags
                    ..clear()
                    ..addAll(n.tags);
                  _text.text = n.text;
                }),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 16),
                color: studioDim,
                onPressed: () => widget.store.remove(n.id),
              ),
            ],
          ),
          if (n.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                n.text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${n.createdAt.substring(0, 16).replaceFirst('T', ' ')} UTC'
              '${n.hash != null && n.hash != widget.asset.hash && widget.asset.hash != null ? ' · asset changed since' : ''}',
              style: TextStyle(
                color:
                    n.hash != null &&
                        widget.asset.hash != null &&
                        n.hash != widget.asset.hash
                    ? studioGold
                    : studioDim,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
