/// Targeted review notes on single assets (a radio clip, a music cue, an
/// atlas animation, a sector background), kept in the browser and synced to
/// the operator-only Worker API (`/api/notes`, worker/notes.mjs).
///
/// Format `demon-attack.notes/v1`, shared by the export download, the Worker
/// and `tools/review_notes.lua`. Like kumbia-kombat's console notes, every
/// note names its asset by a stable reference (`kind / id`) and its source
/// file; it also carries quick tags, an optional playhead offset, the asset's
/// content hash and the build commit, so a worklist can tell whether the
/// asset changed since the note was written.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'review_platform.dart';

const notesSchema = 'demon-attack.notes/v1';

/// The commit the gallery was built from (`--dart-define=BUILD_COMMIT=...`,
/// set by scripts/build-web.sh); empty when unknown.
const buildCommit = String.fromEnvironment('BUILD_COMMIT');

/// Asset kinds, as the Worker accepts them. `page` is a whole page (the
/// console, a gallery page): notes on what it shows or how it plays.
enum ReviewKind { background, atlas, radio, music, scene, page }

/// One reviewable item. [hash] is filled in once known (manifest sha256 for
/// audio, hashed image bytes for atlases).
class ReviewAsset {
  ReviewAsset({
    required this.kind,
    required this.id,
    required this.title,
    required this.source,
    this.hash,
    this.detail = '',
  });
  final ReviewKind kind;
  final String id, title, source, detail;
  String? hash;

  /// Stable reference, the key notes are grouped by: `radio / gloat.d3`.
  String get ref => '${kind.name} / $id';
}

/// A quick tag; [kinds] empty means it is offered for every kind.
class ReviewTag {
  const ReviewTag(this.id, this.label, [this.kinds = const {}]);
  final String id, label;
  final Set<ReviewKind> kinds;
  bool offeredFor(ReviewKind kind) => kinds.isEmpty || kinds.contains(kind);
}

const _audio = {ReviewKind.radio, ReviewKind.music};
const _visual = {ReviewKind.background, ReviewKind.atlas, ReviewKind.scene};

const reviewTags = <ReviewTag>[
  ReviewTag('regenerate', 'regenerate'),
  ReviewTag('refine', 'refine'),
  ReviewTag('needs-growl', 'needs growl', {ReviewKind.radio}),
  ReviewTag('flat-emotion', 'flat emotion', {ReviewKind.radio}),
  ReviewTag('uncompressed-sound', 'uncompressed sound', _audio),
  ReviewTag('clipping', 'clipping', _audio),
  ReviewTag('too-loud', 'too loud', _audio),
  ReviewTag('too-quiet', 'too quiet', _audio),
  ReviewTag('lipsync', 'lip-sync', {ReviewKind.radio}),
  ReviewTag('mix', 'mix', {ReviewKind.music}),
  ReviewTag('loop-seam', 'loop seam', {
    ReviewKind.music,
    ReviewKind.background,
  }),
  ReviewTag('jitter', 'jitter', _visual),
  ReviewTag('off-palette', 'off palette', _visual),
  ReviewTag('timing', 'timing'),
  ReviewTag('bug', 'bug', {ReviewKind.page, ReviewKind.scene}),
  ReviewTag('idea', 'idea', {ReviewKind.page, ReviewKind.scene}),
  ReviewTag('keep', 'good / keep'),
];

/// Worklist order: what to redo first (mirrors tools/review_notes.lua);
/// other tags follow alphabetically, then keep, then untagged.
const worklistTagOrder = [
  'regenerate',
  'refine',
  'needs-growl',
  'flat-emotion',
  'uncompressed-sound',
  'clipping',
  'too-loud',
  'too-quiet',
  'timing',
];

class ReviewNote {
  ReviewNote({
    required this.id,
    required this.kind,
    required this.asset,
    required this.createdAt,
    String? ref,
    this.source,
    this.hash,
    this.tags = const [],
    this.text = '',
    this.offset,
    this.section,
    String? updatedAt,
    this.build,
  }) : ref = ref ?? '${kind.name} / $asset',
       updatedAt = updatedAt ?? createdAt;

  final String id, asset, ref, createdAt;
  final ReviewKind kind;
  final String? source, hash, section, build;
  final List<String> tags;
  final String text;

  /// Playhead seconds (audio or animation) when the note was written.
  final double? offset;
  final String updatedAt;

  ReviewNote copyWith({
    List<String>? tags,
    String? text,
    double? Function()? offset,
    required String updatedAt,
  }) => ReviewNote(
    id: id,
    kind: kind,
    asset: asset,
    ref: ref,
    source: source,
    hash: hash,
    tags: tags ?? this.tags,
    text: text ?? this.text,
    offset: offset != null ? offset() : this.offset,
    section: section,
    createdAt: createdAt,
    updatedAt: updatedAt,
    build: build,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ref': ref,
    'kind': kind.name,
    'asset': asset,
    'source': ?source,
    'hash': ?hash,
    'tags': tags,
    'text': text,
    'offset': ?offset,
    'section': ?section,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'build': ?build,
  };

  /// Null for anything that is not a note of a known kind.
  static ReviewNote? fromJson(Object? data) {
    if (data is! Map) return null;
    final kind = ReviewKind.values
        .where((k) => k.name == data['kind'])
        .firstOrNull;
    final id = data['id'], asset = data['asset'], created = data['createdAt'];
    if (kind == null || id is! String || asset is! String) return null;
    if (created is! String) return null;
    String? text(String key) =>
        data[key] is String ? data[key] as String : null;
    final offset = data['offset'];
    return ReviewNote(
      id: id,
      kind: kind,
      asset: asset,
      ref: text('ref'),
      source: text('source'),
      hash: text('hash'),
      tags: [
        for (final t in data['tags'] is List ? data['tags'] as List : const [])
          if (t is String) t,
      ],
      text: text('text') ?? '',
      offset: offset is num ? offset.toDouble() : null,
      section: text('section'),
      createdAt: created,
      updatedAt: text('updatedAt'),
      build: text('build'),
    );
  }
}

/// All notes, persisted in browser storage; remembers which are not yet on
/// the Worker and which deletions it has not heard about.
class ReviewNotesStore extends ChangeNotifier {
  ReviewNotesStore(
    this.platform, {
    DateTime Function()? clock,
    math.Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? math.Random() {
    _load();
  }

  static const storageKey = 'demon-attack.review.notes.v1';
  static const tokenKey = 'demon-attack.review.token';
  final ReviewPlatform platform;
  final DateTime Function() _clock;
  final math.Random _random;
  final _notes = <String, ReviewNote>{};
  final _unsynced = <String>{};
  final _deleted = <String>{};

  /// Re-reads browser storage before a change, so a page open in another
  /// tab (studio, gallery, console share one store) is not overwritten.
  void _reload() {
    _notes.clear();
    _unsynced.clear();
    _deleted.clear();
    _load();
  }

  void _load() {
    final raw = platform.read(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      for (final n
          in data['notes'] is List ? data['notes'] as List : const []) {
        final note = ReviewNote.fromJson(n);
        if (note != null) _notes[note.id] = note;
      }
      for (final id
          in data['unsynced'] is List ? data['unsynced'] as List : const []) {
        if (id is String && _notes.containsKey(id)) _unsynced.add(id);
      }
      for (final id
          in data['deleted'] is List ? data['deleted'] as List : const []) {
        if (id is String) _deleted.add(id);
      }
    } catch (_) {
      // A damaged store starts empty rather than hiding the studio.
    }
  }

  void _save() {
    platform.write(
      storageKey,
      jsonEncode({
        'schema': notesSchema,
        'notes': [for (final n in _notes.values) n.toJson()],
        'unsynced': _unsynced.toList(),
        'deleted': _deleted.toList(),
      }),
    );
    notifyListeners();
  }

  String get _now => _clock().toUtc().toIso8601String();

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final stamp = _clock().millisecondsSinceEpoch.toRadixString(36);
    final tail = List.generate(
      8,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return 'n$stamp-$tail';
  }

  /// Newest first.
  List<ReviewNote> get notes =>
      _notes.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ReviewNote> notesFor(String ref) =>
      notes.where((n) => n.ref == ref).toList();

  bool has(String ref) => _notes.values.any((n) => n.ref == ref);

  /// Tags used on [ref] (for list markers).
  Set<String> tagsFor(String ref) => {
    for (final n in _notes.values)
      if (n.ref == ref) ...n.tags,
  };

  int get count => _notes.length;

  /// Notes and deletions the Worker has not received yet.
  int get pending => _unsynced.length + _deleted.length;

  ReviewNote add(
    ReviewAsset asset, {
    List<String> tags = const [],
    String text = '',
    double? offset,
    String? section,
  }) {
    _reload();
    final note = ReviewNote(
      id: _newId(),
      kind: asset.kind,
      asset: asset.id,
      ref: asset.ref,
      source: asset.source,
      hash: asset.hash,
      tags: List.unmodifiable(tags),
      text: text.trim(),
      offset: offset == null ? null : (offset * 100).roundToDouble() / 100,
      section: (section?.isEmpty ?? true) ? null : section,
      createdAt: _now,
      build: buildCommit.isEmpty ? null : buildCommit,
    );
    _notes[note.id] = note;
    _unsynced.add(note.id);
    _save();
    return note;
  }

  void edit(String id, {List<String>? tags, String? text}) {
    _reload();
    final old = _notes[id];
    if (old == null) return;
    _notes[id] = old.copyWith(tags: tags, text: text?.trim(), updatedAt: _now);
    _unsynced.add(id);
    _save();
  }

  void remove(String id) {
    _reload();
    if (_notes.remove(id) == null) return;
    // A note the Worker never saw needs no server delete.
    if (!_unsynced.remove(id)) _deleted.add(id);
    _save();
  }

  /// Adds notes from an export or the Worker; for one id the newer
  /// `updatedAt` wins. Returns how many changed.
  int merge(Iterable<ReviewNote> incoming, {bool fromServer = false}) {
    _reload();
    var changed = 0;
    for (final note in incoming) {
      if (_deleted.contains(note.id)) continue;
      final mine = _notes[note.id];
      if (mine != null && mine.updatedAt.compareTo(note.updatedAt) >= 0) {
        if (fromServer && mine.updatedAt == note.updatedAt) {
          _unsynced.remove(note.id);
        }
        continue;
      }
      _notes[note.id] = note;
      if (fromServer) {
        _unsynced.remove(note.id);
      } else {
        _unsynced.add(note.id);
      }
      changed++;
    }
    _save();
    return changed;
  }

  /// Notes in an export file (`{"notes": [...]}` or a bare list).
  static List<ReviewNote> parse(String text) {
    final data = jsonDecode(text);
    final list = data is Map ? data['notes'] : data;
    if (list is! List) throw const FormatException('No notes array');
    return [for (final n in list) ?ReviewNote.fromJson(n)];
  }

  static const draftKey = 'demon-attack.review.drafts.v1';

  Map<String, Object?> _drafts() {
    try {
      final data = jsonDecode(platform.read(draftKey) ?? '{}');
      return data is Map<String, Object?> ? data : {};
    } catch (_) {
      return {};
    }
  }

  /// The unsaved text and tags typed for [ref], kept in browser storage so a
  /// reload does not lose them; null when there is none.
  ({String text, List<String> tags})? draft(String ref) {
    final d = _drafts()[ref];
    if (d is! Map) return null;
    final text = d['text'] is String ? d['text'] as String : '';
    final tags = [
      for (final t in d['tags'] is List ? d['tags'] as List : const [])
        if (t is String) t,
    ];
    if (text.isEmpty && tags.isEmpty) return null;
    return (text: text, tags: tags);
  }

  /// Remembers (or, when empty, forgets) the draft for [ref].
  void saveDraft(String ref, String text, Iterable<String> tags) {
    final drafts = _drafts();
    if (text.trim().isEmpty && tags.isEmpty) {
      if (drafts.remove(ref) == null) return;
    } else {
      drafts[ref] = {'text': text, 'tags': tags.toList()};
    }
    platform.write(draftKey, jsonEncode(drafts));
  }

  /// Picks up notes written in another tab since this page loaded.
  void refresh() {
    _reload();
    notifyListeners();
  }

  /// Every note as a markdown worklist to paste to an agent: grouped by tag
  /// in fix-first order (tools/review_notes.lua prints the same layout), each
  /// line naming the asset, its source file, the playhead and the build.
  String worklistMarkdown() {
    final all = notes.reversed.toList(); // oldest first
    final buffer = StringBuffer()
      ..writeln('# Demon Attack review notes')
      ..writeln()
      ..writeln(
        '${all.length} note${all.length == 1 ? '' : 's'}, copied $_now'
        '${buildCommit.isEmpty ? '' : ' from build $buildCommit'}.',
      )
      ..writeln(
        'Each line: asset ref, source file, playhead or section, then the '
        'note. Hashes say which version of the asset was reviewed.',
      );
    if (all.isEmpty) return buffer.toString();
    final groups = <String, List<ReviewNote>>{};
    for (final n in all) {
      for (final t in n.tags.isEmpty ? const ['untagged'] : n.tags) {
        (groups[t] ??= []).add(n);
      }
    }
    final order = [
      for (final t in worklistTagOrder)
        if (groups.containsKey(t)) t,
      for (final t in groups.keys.toList()..sort())
        if (!worklistTagOrder.contains(t) && t != 'keep' && t != 'untagged') t,
      if (groups.containsKey('keep')) 'keep',
      if (groups.containsKey('untagged')) 'untagged',
    ];
    for (final tag in order) {
      final label = reviewTags.where((t) => t.id == tag).firstOrNull?.label;
      buffer
        ..writeln()
        ..writeln('## ${label ?? tag} (${groups[tag]!.length})')
        ..writeln();
      for (final n in groups[tag]!) {
        final where = [
          if (n.offset != null) '@ ${n.offset!.toStringAsFixed(2)} s',
          ?n.section,
        ].join(', ');
        final meta = [
          ?n.source,
          if (n.hash != null)
            'sha ${n.hash!.substring(0, math.min(12, n.hash!.length))}',
          if (n.build != null) 'build ${n.build}',
          'noted ${n.createdAt.substring(0, math.min(16, n.createdAt.length))}',
        ].join(' · ');
        buffer.writeln(
          '- **${n.ref}**${where.isEmpty ? '' : ' ($where)'}: '
          '${n.text.isEmpty ? '(no text)' : n.text.replaceAll('\n', ' ')}',
        );
        buffer.writeln('  - $meta');
      }
    }
    return buffer.toString();
  }

  /// The worklist download name.
  String get worklistFilename =>
      'demon-attack-notes-${_now.substring(0, 10)}.md';

  /// The export download: every note, oldest first.
  String exportJson() {
    final list = notes.reversed.map((n) => n.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'schema': notesSchema,
      'exportedAt': _now,
      'build': buildCommit.isEmpty ? null : buildCommit,
      'count': list.length,
      'notes': list,
    });
  }

  String get exportFilename =>
      'demon-attack-notes-${_now.substring(0, 19).replaceAll(':', '')}.json';

  String get token => platform.read(tokenKey) ?? '';
  set token(String value) {
    platform.write(tokenKey, value.trim());
    notifyListeners();
  }

  /// Pushes unsent notes and deletions, then pulls every note.
  Future<String> sync(NotesApi api) async {
    final token = this.token;
    if (token.isEmpty) return 'Set the operator token first';
    final sending = [for (final id in _unsynced) ?_notes[id]];
    for (var i = 0; i < sending.length; i += 200) {
      await api.push(
        token,
        sending.sublist(i, math.min(sending.length, i + 200)),
      );
    }
    _unsynced.removeAll(sending.map((n) => n.id));
    for (final id in _deleted.toList()) {
      await api.delete(token, id);
      _deleted.remove(id);
    }
    _save();
    final remote = await api.fetchAll(token);
    final changed = merge(remote, fromServer: true);
    return 'Synced: sent ${sending.length}, received $changed, '
        '${remote.length} on the server';
  }
}

/// Client of the Worker's `/api/notes` (operator token required).
class NotesApi {
  NotesApi(this.send, {Uri? base})
    : base = base ?? Uri.base.resolve('/api/notes');

  /// Sends one request: (method, url, headers, body) -> (status, body).
  final Future<(int, String)> Function(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  )
  send;
  final Uri base;

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'content-type': 'application/json',
  };

  Future<String> _call(
    String method,
    Uri url,
    String token, [
    String? body,
  ]) async {
    final (status, text) = await send(method, url, _headers(token), body);
    if (status >= 300) {
      var message = text;
      try {
        message = (jsonDecode(text) as Map)['error'] as String? ?? text;
      } catch (_) {}
      throw NotesApiException(status, message);
    }
    return text;
  }

  Future<List<ReviewNote>> fetchAll(String token) async =>
      ReviewNotesStore.parse(await _call('GET', base, token));

  Future<void> push(String token, List<ReviewNote> notes) => _call(
    'POST',
    base,
    token,
    jsonEncode({
      'notes': [for (final n in notes) n.toJson()],
    }),
  );

  Future<void> delete(String token, String id) =>
      _call('DELETE', base.replace(queryParameters: {'id': id}), token);
}

class NotesApiException implements Exception {
  const NotesApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'HTTP $status: $message';
}
