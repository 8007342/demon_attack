// The art gallery and asset review studio; not part of the shipped app.
//
//   flutter build web -t lib/gallery_main.dart --base-href /gallery/
//
// /gallery/ lists the scene pages grouped by game area, each labelled with
// the OpenSpec changes it shows; /gallery/?page=<id> opens one (&tile=<n>
// one of its tiles). Every tile is the game's own DemonScene and its
// presentation pipeline on a model started like the game's
// (lib/review/gallery_scenes.dart), so screenshots show what the game
// draws today.
//
// /studio (or ?page=studio) opens the asset review studio (lib/review/):
// backgrounds, atlas animations, these scenes, radio clips and music cues,
// each with targeted review notes (&tab=radio&item=<clip id> deep-links
// one).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'review/dev_nav.dart';
import 'review/gallery_scenes.dart';
import 'review/page_notes.dart';
import 'review/review_catalog.dart';
import 'review/review_studio.dart';
import 'services/audio.dart';

void main() {
  // The gallery loads the game's audio script (web/index.html is shared);
  // its menu music must not start here. The studio plays its own audio.
  audioMute(true);
  runApp(const GalleryApp());
}

/// Whether [path] is the studio's own address, /studio (the Worker serves
/// this app there; /gallery/?page=studio still works).
bool isStudioPath(String path) {
  var p = path.toLowerCase();
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p == '/studio';
}

const _ink = Color(0xFF0B0A1C);
const _mint = Color(0xFF70F5D5);
const _gold = Color(0xFFF4C35A);
const _dim = Color(0xFF8D9EB3);
const _line = Color(0xFF2B4254);

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, this.query, this.path});

  /// The address's query and path (tests); defaults to [Uri.base].
  final Map<String, String>? query;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final query = this.query ?? Uri.base.queryParameters;
    final page =
        query['page'] ??
        (isStudioPath(path ?? Uri.base.path) ? 'studio' : null);
    if (page == 'studio' || page == 'review') {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Demon Attack asset review',
        home: ReviewStudio(
          sceneBuilder: (page) => GalleryPage(page: page),
          initialTab: StudioTab.values
              .where((t) => t.name == query['tab'])
              .firstOrNull,
          initialItem: query['item'],
        ),
      );
    }
    final scene = page == null ? null : scenePage(page);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Demon Attack gallery',
      home: Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GalleryHeader(
                scene: scene,
                unknown: page != null && scene == null,
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: page == null
                    ? const GalleryIndex()
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: GalleryPage(
                              page: page,
                              only: int.tryParse(query['tile'] ?? ''),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: PageNotesButton(asset: sceneAsset(page)),
                          ),
                        ],
                      ),
              ),
              const DevFooter(page: DevPage.gallery),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gallery's top bar: the page navigation, and on a scene page its
/// title, area and source changes with a link back to the index.
class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({this.scene, this.unknown = false});
  final ScenePage? scene;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final s = scene;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const DevNavBar(current: DevPage.gallery),
          if (s != null || unknown)
            TextButton.icon(
              key: const ValueKey('gallery-index'),
              style: TextButton.styleFrom(foregroundColor: _dim),
              onPressed: () => openDevPage(DevPage.gallery),
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('ALL SCENES', style: TextStyle(fontSize: 10)),
            ),
          if (s != null)
            Text.rich(
              key: const ValueKey('gallery-scene-label'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '${s.area.label} · ',
                    style: const TextStyle(color: _gold),
                  ),
                  TextSpan(
                    text: s.title,
                    style: const TextStyle(color: _mint),
                  ),
                  TextSpan(
                    text: '   ${s.sourceLabel}',
                    style: const TextStyle(color: _dim),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 11, letterSpacing: 1),
            ),
        ],
      ),
    );
  }
}

/// /gallery/: every scene page, grouped by game area.
class GalleryIndex extends StatelessWidget {
  const GalleryIndex({super.key, this.onOpen});

  /// Opens a scene page (tests replace it); defaults to `?page=<id>`.
  final void Function(ScenePage page)? onOpen;

  void _open(ScenePage p) => launchScene(p.id);

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    children: [
      for (final area in GameArea.values)
        if (scenePages.any((p) => p.area == area)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              area.label,
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          for (final p in scenePages.where((p) => p.area == area))
            ListTile(
              key: ValueKey('gallery-scene-${p.id}'),
              dense: true,
              title: Text(p.title, style: const TextStyle(color: _mint)),
              subtitle: Text(
                '${p.live ? 'live run' : 'staged'} · ${p.sourceLabel}',
                style: const TextStyle(color: _dim, fontSize: 11),
              ),
              trailing: Text(
                '?page=${p.id}',
                style: const TextStyle(
                  color: _dim,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () => (onOpen ?? _open)(p),
            ),
        ],
    ],
  );
}

/// Opens scene page [id] in this tab.
void launchScene(String id) => openDevPageAt('/gallery/?page=$id');

/// One scene page: a grid of its tiles, built once (a rebuild of the
/// studio around it keeps the runs going).
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.page, this.only});
  final String page;
  final int? only;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late List<GalleryTile> all = galleryTiles(widget.page);
  late List<Widget> built = [for (final t in all) t.build()];

  @override
  void didUpdateWidget(GalleryPage old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      all = galleryTiles(widget.page);
      built = [for (final t in all) t.build()];
    }
  }

  @override
  Widget build(BuildContext context) {
    var tiles = built;
    final only = widget.only;
    if (only != null && only < tiles.length) tiles = [tiles[only]];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = tiles.length == 1
            ? 1
            : (box.maxWidth > 900 ? math.min(4, tiles.length) : 2);
        final rows = (tiles.length / cols).ceil();
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++)
                      Expanded(
                        child: r * cols + c < tiles.length
                            ? tiles[r * cols + c]
                            : const SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
