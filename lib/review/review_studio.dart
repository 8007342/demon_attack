/// The asset review studio (`/gallery/?page=studio`, linked from /console):
/// browse and play every background, atlas animation, staged scene, radio
/// clip and music cue, and pin targeted notes to each one. Notes live in
/// the browser, export as JSON and sync to the operator-only `/api/notes`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../comms/comms_bank.dart';
import 'notes_panel.dart';
import 'page_notes.dart';
import 'review_audio_views.dart';
import 'review_catalog.dart';
import 'review_notes.dart';
import 'review_platform.dart';
import 'review_views.dart';
import 'sha256.dart';

enum StudioTab { backgrounds, sprites, scenes, radio, music, notes }

typedef SendRequest = Future<(int, String)> Function(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
);

Future<(int, String)> httpSend(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
) async {
  final request = http.Request(method, url)..headers.addAll(headers);
  if (body != null) request.body = body;
  final response = await http.Response.fromStream(await request.send());
  return (response.statusCode, response.body);
}

Future<String?> fetchText(String path) async {
  try {
    final response = await http.get(Uri.base.resolve(path));
    return response.statusCode == 200 ? response.body : null;
  } catch (_) {
    return null;
  }
}

class ReviewStudio extends StatefulWidget {
  const ReviewStudio({
    super.key,
    required this.sceneBuilder,
    this.platform,
    this.loadText = fetchText,
    this.send = httpSend,
    this.initialTab,
    this.initialItem,
  });

  /// Builds a staged gallery page (lib/gallery_main.dart) by name.
  final Widget Function(String page) sceneBuilder;
  final ReviewPlatform? platform;

  /// Reads a text file served next to the page (the audio manifests).
  final Future<String?> Function(String path) loadText;
  final SendRequest send;
  final StudioTab? initialTab;
  final String? initialItem;

  @override
  State<ReviewStudio> createState() => _ReviewStudioState();
}

class _ReviewStudioState extends State<ReviewStudio> {
  late final ReviewPlatform platform =
      widget.platform ?? createReviewPlatform();
  late final store = ReviewNotesStore(platform);
  late final ReviewAudio audio = platform.audio();
  late final api = NotesApi(widget.send);
  final link = PlayheadLink();

  late StudioTab tab = widget.initialTab ?? StudioTab.radio;
  bool detail = false;
  String status = '';

  // Catalog.
  final backgrounds = backgroundAssets();
  List<AtlasAnim> anims = atlasAnimations();
  final clips = radioClips();
  List<MusicCue> cues = const [];
  bool radioMeta = false;
  final _assets = <String, ReviewAsset>{};
  final _hashes = <String, Future<String?>>{};

  // Selections.
  int background = 0;
  String? anim, clip, cue, scene;

  // Filters.
  String search = '', group = '', speaker = '', emotion = '', event = '';
  String side = 'all', tagFilter = '';
  int level = -1;
  bool notedOnly = false, stemsOnly = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
    _loadMeta();
    final item = widget.initialItem;
    if (item != null) _open(tab, item);
    clip ??= clips.isEmpty ? null : clips.first.line.id;
    anim ??= anims.isEmpty ? null : anims.first.asset().id;
    scene ??= scenePages.first.$1;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    audio.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final ship = await rootBundle.loadString(
        'assets/images/ship-weapons.json',
        // Uncached: the game's scene caches this file too, and a shared
        // future must never outlive the zone that started it (tests).
        cache: false,
      );
      final data = jsonDecode(ship);
      if (data is Map<String, Object?>) {
        anims = atlasAnimations(shipWeapons: data);
      }
    } catch (_) {}
    final comms = await widget.loadText('audio/comms/manifest.json');
    if (comms != null) {
      try {
        final data = jsonDecode(comms);
        final entries = data is Map ? data['clips'] : null;
        if (entries is Map) {
          for (final c in clips) {
            final meta = entries[c.line.id];
            if (meta is Map) c.meta = meta.cast<String, Object?>();
            _assets.remove(c.asset().ref);
          }
          radioMeta = true;
        }
      } catch (_) {}
    }
    final music = await widget.loadText('audio/music/manifest.json');
    if (music != null) {
      try {
        final data = jsonDecode(music);
        if (data is Map<String, Object?>) cues = musicCues(data);
      } catch (_) {}
    }
    final item = widget.initialItem;
    if (item != null && tab == StudioTab.music) cue ??= item;
    cue ??= cues.isEmpty ? null : cues.first.name;
    if (mounted) setState(() {});
  }

  /// One shared asset object per reference, so a computed hash sticks.
  ReviewAsset _asset(ReviewAsset fresh) {
    final known = _assets[fresh.ref];
    if (known != null) return known;
    _assets[fresh.ref] = fresh;
    _hash(fresh);
    return fresh;
  }

  /// Content hash: the manifest sha256 for audio, hashed bytes for images
  /// (a digest of the per-file hashes when an asset spans several files).
  void _hash(ReviewAsset asset) {
    if (asset.hash != null) return;
    final files = switch (asset.kind) {
      ReviewKind.atlas => [
        for (final a in anims)
          if (a.asset().id == asset.id) a.path,
      ].take(1).toList(),
      ReviewKind.background => backgroundFiles(
        int.parse(asset.id.split('-').last) - 1,
      ),
      ReviewKind.scene => const [
        'assets/images/combat.png',
        'assets/images/sentinel-effects.png',
        'assets/images/ship-weapons.png',
      ],
      _ => const <String>[],
    };
    if (files.isEmpty) return;
    Future<String?> one(String path) => _hashes[path] ??= () async {
      try {
        final data = await rootBundle.load(path);
        return sha256Hex(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } catch (_) {
        return null;
      }
    }();
    Future.wait(files.map(one)).then((hashes) {
      if (hashes.any((h) => h == null)) return;
      asset.hash = files.length == 1
          ? hashes.single
          : sha256Hex(
              utf8.encode(
                [
                  for (var i = 0; i < files.length; i++)
                    '${files[i]}:${hashes[i]}',
                ].join('\n'),
              ),
            );
      if (mounted) setState(() {});
    });
  }

  // ------------------------------------------------------------- lists

  List<RadioClip> get visibleClips => [
    for (final c in clips)
      if ((speaker.isEmpty || c.line.speaker == speaker) &&
          (side == 'all' || (side == 'demon') == c.demon) &&
          (emotion.isEmpty || c.emotion == emotion) &&
          (event.isEmpty || c.event == event) &&
          (!notedOnly || store.has(c.asset().ref)) &&
          (search.isEmpty ||
              '${c.line.id} ${c.subtitle} ${c.character.name}'
                  .toLowerCase()
                  .contains(search)))
        c,
  ];

  List<AtlasAnim> get visibleAnims => [
    for (final a in anims)
      if ((group.isEmpty || a.group == group) &&
          (!notedOnly || store.has(a.asset().ref)) &&
          (search.isEmpty ||
              '${a.group} ${a.title}'.toLowerCase().contains(search)))
        a,
  ];

  List<MusicCue> get visibleCues => [
    for (final c in cues)
      if ((level < 0 || c.level == level) &&
          (!stemsOnly || c.stem) &&
          (!notedOnly || store.has(c.asset().ref)) &&
          (search.isEmpty || c.name.contains(search)))
        c,
  ];

  List<ReviewNote> get visibleNotes => [
    for (final n in store.notes)
      if ((tagFilter.isEmpty || n.tags.contains(tagFilter)) &&
          (search.isEmpty ||
              '${n.ref} ${n.text}'.toLowerCase().contains(search)))
        n,
  ];

  /// Opens [item] (an asset id) in [to], clearing filters that would hide it.
  void _open(StudioTab to, String item) {
    tab = to;
    detail = true;
    search = '';
    notedOnly = false;
    switch (to) {
      case StudioTab.backgrounds:
        background = (int.tryParse(item.split('-').last) ?? 1).clamp(1, 5) - 1;
      case StudioTab.sprites:
        group = '';
        anim = item;
      case StudioTab.scenes:
        scene = item;
      case StudioTab.radio:
        speaker = emotion = event = '';
        side = 'all';
        clip = item;
      case StudioTab.music:
        level = -1;
        stemsOnly = false;
        cue = item;
      case StudioTab.notes:
        break;
    }
  }

  void _openNote(ReviewNote n) => setState(
    () => _open(switch (n.kind) {
      ReviewKind.background => StudioTab.backgrounds,
      ReviewKind.atlas => StudioTab.sprites,
      ReviewKind.scene => StudioTab.scenes,
      ReviewKind.radio => StudioTab.radio,
      ReviewKind.music => StudioTab.music,
      ReviewKind.page => StudioTab.notes,
    }, n.asset),
  );

  ReviewAsset? get selectedAsset {
    switch (tab) {
      case StudioTab.backgrounds:
        return _asset(backgrounds[background]);
      case StudioTab.sprites:
        final a = anims.where((a) => a.asset().id == anim).firstOrNull;
        return a == null ? null : _asset(a.asset());
      case StudioTab.scenes:
        final s = scenePages.where((p) => p.$1 == scene).firstOrNull;
        return s == null ? null : _asset(sceneAsset(s.$1, s.$2));
      case StudioTab.radio:
        final c = clips.where((c) => c.line.id == clip).firstOrNull;
        return c == null ? null : _asset(c.asset());
      case StudioTab.music:
        final c = cues.where((c) => c.name == cue).firstOrNull;
        return c == null ? null : _asset(c.asset());
      case StudioTab.notes:
        return null;
    }
  }

  // ------------------------------------------------------------- actions

  void _export() {
    platform.download(
      store.exportFilename,
      store.exportJson(),
      type: 'application/json',
    );
    setState(() => status = 'Exported ${store.count} notes');
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import notes JSON'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste an export or a GET /api/notes response',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      final changed = store.merge(ReviewNotesStore.parse(text));
      setState(() => status = 'Imported $changed notes');
    } catch (e) {
      setState(() => status = 'Import failed: $e');
    }
  }

  Future<void> _tokenDialog() async {
    final controller = TextEditingController(text: store.token);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Operator token'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes always stay in this browser. With the Worker\'s NOTES_TOKEN '
                'they also sync to /api/notes, where the agent can read them.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('token-field'),
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'NOTES_TOKEN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) store.token = controller.text;
    controller.dispose();
  }

  Future<void> _sync() async {
    if (store.token.isEmpty) {
      await _tokenDialog();
      if (store.token.isEmpty) return;
    }
    setState(() => status = 'Syncing…');
    try {
      final result = await store.sync(api);
      if (mounted) setState(() => status = result);
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Sync failed: $e (notes are kept locally)');
      }
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: studioMint,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: studioInk,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: studioPanel,
          titleSpacing: 12,
          title: const Text(
            'ASSET REVIEW',
            style: TextStyle(fontSize: 14, letterSpacing: 2, color: studioMint),
          ),
          actions: [
            if (status.isNotEmpty)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: studioDim, fontSize: 11),
                  ),
                ),
              ),
            IconButton(
              key: const ValueKey('studio-copy'),
              tooltip: 'Copy all notes as markdown, to paste to an agent',
              onPressed: () async {
                final s = await copyWorklist(store);
                if (mounted) setState(() => status = s);
              },
              icon: const Icon(Icons.content_copy),
            ),
            IconButton(
              key: const ValueKey('studio-save-md'),
              tooltip: 'Save all notes as a markdown file',
              onPressed: () => setState(() => status = saveWorklist(store)),
              icon: const Icon(Icons.description),
            ),
            IconButton(
              key: const ValueKey('studio-export'),
              tooltip: 'Export all notes as JSON',
              onPressed: _export,
              icon: const Icon(Icons.download),
            ),
            IconButton(
              tooltip: 'Import notes JSON',
              onPressed: _import,
              icon: const Icon(Icons.upload),
            ),
            IconButton(
              key: const ValueKey('studio-sync'),
              tooltip: store.pending > 0
                  ? 'Sync with /api/notes (${store.pending} pending)'
                  : 'Sync with /api/notes',
              onPressed: _sync,
              icon: Badge(
                isLabelVisible: store.pending > 0,
                label: Text('${store.pending}'),
                child: const Icon(Icons.cloud_sync),
              ),
            ),
            IconButton(
              tooltip: 'Operator token',
              onPressed: _tokenDialog,
              icon: const Icon(Icons.key),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final t in StudioTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 6),
                      child: ChoiceChip(
                        key: ValueKey('tab-${t.name}'),
                        label: Text(
                          t == StudioTab.notes
                              ? 'notes (${store.count})'
                              : t.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: tab == t,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          tab = t;
                          detail = false;
                          search = '';
                          link.clear();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: LayoutBuilder(builder: (context, box) => _layout(box.maxWidth)),
      ),
    );
  }

  Widget _layout(double width) {
    final asset = selectedAsset;
    final view = _view();
    final notes = asset == null
        ? null
        : NotesPanel(asset: asset, store: store, link: link);
    if (width >= 1100) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 300, child: _listPane()),
          const VerticalDivider(width: 1, color: studioLine),
          Expanded(child: view),
          if (notes != null) ...[
            const VerticalDivider(width: 1, color: studioLine),
            SizedBox(width: 360, child: notes),
          ],
        ],
      );
    }
    if (width >= 720) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: _listPane()),
          const VerticalDivider(width: 1, color: studioLine),
          Expanded(
            child: Column(
              children: [
                Expanded(flex: 3, child: view),
                if (notes != null) ...[
                  const Divider(height: 1, color: studioLine),
                  Expanded(flex: 2, child: notes),
                ],
              ],
            ),
          ),
        ],
      );
    }
    // Phone: the list, or one item with its notes underneath.
    if (!detail || tab == StudioTab.notes) return _listPane();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => detail = false),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('list'),
          ),
        ),
        Expanded(flex: 3, child: view),
        if (notes != null) ...[
          const Divider(height: 1, color: studioLine),
          Expanded(flex: 2, child: notes),
        ],
      ],
    );
  }

  Widget _view() {
    switch (tab) {
      case StudioTab.backgrounds:
        return BackgroundView(sector: background, link: link);
      case StudioTab.sprites:
        final a = anims.where((a) => a.asset().id == anim).firstOrNull;
        return a == null
            ? _empty('Pick an animation')
            : AtlasView(anim: a, link: link);
      case StudioTab.scenes:
        link.clear();
        return KeyedSubtree(
          key: ValueKey('scene-$scene'),
          child: widget.sceneBuilder(scene ?? 'creatures'),
        );
      case StudioTab.radio:
        final list = visibleClips;
        final c = clips.where((c) => c.line.id == clip).firstOrNull;
        if (c == null) return _empty('Pick a clip');
        final i = list.indexOf(c);
        return RadioView(
          clip: c,
          audio: audio,
          link: link,
          onNext: list.isEmpty
              ? null
              : () =>
                    setState(() => clip = list[(i + 1) % list.length].line.id),
          onPrevious: list.isEmpty
              ? null
              : () => setState(
                  () =>
                      clip = list[(i - 1 + list.length) % list.length].line.id,
                ),
        );
      case StudioTab.music:
        final c = cues.where((c) => c.name == cue).firstOrNull;
        return c == null
            ? _empty(
                cues.isEmpty
                    ? 'Loading audio/music/manifest.json…'
                    : 'Pick a cue',
              )
            : MusicView(cue: c, audio: audio, link: link);
      case StudioTab.notes:
        return _summary();
    }
  }

  Widget _empty(String text) => Center(
    child: Text(text, style: const TextStyle(color: studioDim)),
  );

  Widget _searchField(String hint) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: TextField(
      key: const ValueKey('studio-search'),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 18),
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 12),
      onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> pick,
  ) => SizedBox(
    width: 130,
    child: DropdownButton<String>(
      key: ValueKey('filter-$label'),
      value: options.contains(value) ? value : '',
      isDense: true,
      isExpanded: true,
      style: const TextStyle(fontSize: 11, color: Colors.white),
      items: [
        DropdownMenuItem(value: '', child: Text('any $label')),
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => pick(v ?? '')),
    ),
  );

  Widget _notedToggle() => FilterChip(
    label: const Text('with notes', style: TextStyle(fontSize: 11)),
    selected: notedOnly,
    visualDensity: VisualDensity.compact,
    onSelected: (v) => setState(() => notedOnly = v),
  );

  Widget _row({
    required String title,
    required String subtitle,
    required String ref,
    required bool selected,
    required VoidCallback onTap,
    Key? key,
  }) {
    final tags = store.tagsFor(ref);
    final noted = store.has(ref);
    return ListTile(
      key: key,
      dense: true,
      selected: selected,
      selectedTileColor: studioMint.withValues(alpha: .1),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: studioDim),
      ),
      trailing: noted
          ? Wrap(
              spacing: 2,
              children: [
                for (final t in tags.take(3))
                  Container(width: 8, height: 8, color: tagColor(t)),
                if (tags.isEmpty)
                  Container(width: 8, height: 8, color: studioDim),
              ],
            )
          : null,
      onTap: () => setState(() {
        detail = true;
        onTap();
      }),
    );
  }

  Widget _listPane() {
    switch (tab) {
      case StudioTab.backgrounds:
        return ListView(
          children: [
            for (var s = 0; s < backgrounds.length; s++)
              _row(
                title: backgrounds[s].title,
                subtitle: backgrounds[s].detail,
                ref: backgrounds[s].ref,
                selected: background == s,
                onTap: () => background = s,
              ),
          ],
        );
      case StudioTab.scenes:
        return ListView(
          children: [
            for (final (page, title) in scenePages)
              _row(
                title: page,
                subtitle: title,
                ref: sceneAsset(page, title).ref,
                selected: scene == page,
                onTap: () => scene = page,
              ),
          ],
        );
      case StudioTab.sprites:
        final list = visibleAnims;
        final groups = {for (final a in anims) a.group}.toList();
        return Column(
          children: [
            _searchField('Search animations'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'atlas group',
                      group,
                      groups,
                      (v) => group = v,
                    ),
                  ),
                  _notedToggle(),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final a = list[i];
                  final asset = a.asset();
                  return _row(
                    title: asset.title,
                    subtitle: '${asset.detail} · ${a.image}',
                    ref: asset.ref,
                    selected: anim == asset.id,
                    onTap: () => anim = asset.id,
                  );
                },
              ),
            ),
          ],
        );
      case StudioTab.radio:
        final list = visibleClips;
        final emotions = {
          for (final c in clips)
            if (c.emotion.isNotEmpty) c.emotion,
        }.toList()..sort();
        final events = {for (final c in clips) c.event}.toList()..sort();
        return Column(
          children: [
            _searchField('Search lines, ids, names'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final s in ['all', 'human', 'demon'])
                    ChoiceChip(
                      key: ValueKey('side-$s'),
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      selected: side == s,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => side = s),
                    ),
                  _dropdown(
                    'speaker',
                    speaker,
                    commsCast.keys.toList(),
                    (v) => speaker = v,
                  ),
                  _dropdown('emotion', emotion, emotions, (v) => emotion = v),
                  _dropdown('event', event, events, (v) => event = v),
                  _notedToggle(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                '${list.length} of ${clips.length} clips${radioMeta ? '' : ' · manifest not loaded'}',
                style: const TextStyle(color: studioDim, fontSize: 10),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return _row(
                    key: ValueKey('clip-${c.line.id}'),
                    title: '${c.character.name} · ${c.line.id}',
                    subtitle:
                        '${c.emotion.isEmpty ? '' : '[${c.emotion}] '}${c.subtitle}',
                    ref: c.asset().ref,
                    selected: clip == c.line.id,
                    onTap: () => clip = c.line.id,
                  );
                },
              ),
            ),
          ],
        );
      case StudioTab.music:
        final list = visibleCues;
        return Column(
          children: [
            _searchField('Search cues'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final l in [-1, 1, 2, 3, 4, 5, 0])
                    ChoiceChip(
                      label: Text(
                        l < 0
                            ? 'all'
                            : l == 0
                            ? 'other'
                            : 'L$l',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: level == l,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => level = l),
                    ),
                  FilterChip(
                    label: const Text(
                      'stems & accents',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: stemsOnly,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => setState(() => stemsOnly = v),
                  ),
                  _notedToggle(),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return _row(
                    title: c.name,
                    subtitle: c.asset().detail,
                    ref: c.asset().ref,
                    selected: cue == c.name,
                    onTap: () => cue = c.name,
                  );
                },
              ),
            ),
          ],
        );
      case StudioTab.notes:
        final list = visibleNotes;
        final used = {for (final n in store.notes) ...n.tags};
        return Column(
          children: [
            _searchField('Search notes'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text(
                      'all tags',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: tagFilter.isEmpty,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => tagFilter = ''),
                  ),
                  for (final t in reviewTags)
                    if (used.contains(t.id))
                      ChoiceChip(
                        label: Text(
                          t.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: tagFilter == t.id,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => tagFilter = t.id),
                      ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final n = list[i];
                  return ListTile(
                    dense: true,
                    title: Text(n.ref, style: const TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${n.tags.join(', ')}${n.offset == null ? '' : ' @ ${clockLabel(n.offset!)}'}'
                      '${n.text.isEmpty ? '' : ' — ${n.text}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: studioDim),
                    ),
                    onTap: () => _openNote(n),
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _summary() {
    final byTag = <String, int>{};
    final byKind = <String, int>{};
    for (final n in store.notes) {
      for (final t in n.tags.isEmpty ? const ['untagged'] : n.tags) {
        byTag[t] = (byTag[t] ?? 0) + 1;
      }
      byKind[n.kind.name] = (byKind[n.kind.name] ?? 0) + 1;
    }
    TextStyle s(double size, [Color color = Colors.white]) =>
        TextStyle(fontSize: size, color: color);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${store.count} notes · ${store.pending} not yet on the server',
          style: s(16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final MapEntry(:key, :value) in byTag.entries)
              Text('$key $value', style: s(12, tagColor(key))),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final MapEntry(:key, :value) in byKind.entries)
              Text('$key $value', style: s(12, studioDim)),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download),
              label: const Text('Export JSON'),
            ),
            OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload),
              label: const Text('Import JSON'),
            ),
            OutlinedButton.icon(
              onPressed: _sync,
              icon: const Icon(Icons.cloud_sync),
              label: const Text('Sync /api/notes'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Turn an export into a worklist grouped by tag:\n'
          '  lua tools/review_notes.lua demon-attack-notes-….json > worklist.md\n'
          'or straight from the Worker:\n'
          '  curl -sH "authorization: Bearer \$NOTES_TOKEN" https://demonattack.tlatoani.net/api/notes \\\n'
          '    | lua tools/review_notes.lua -',
          style: const TextStyle(
            fontSize: 11,
            color: studioDim,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
