// --- dev-pages-overhaul: one navigation bar and one footer for the three
// dev pages (/console, /gallery/, /studio), design §4.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/build_version_label.dart'; // --- build-version

/// The three dev pages and their addresses.
enum DevPage {
  console('CONSOLE', '/console', Icons.tune),
  gallery('GALLERY', '/gallery/', Icons.grid_view),
  studio('STUDIO', '/studio', Icons.rate_review);

  const DevPage(this.label, this.path, this.icon);
  final String label, path;
  final IconData icon;
}

const _mint = Color(0xFF70F5D5);
const _dim = Color(0xFF8D9EB3);
const _ink = Color(0xFF0B0A1C);

/// Opens [page] in this tab (each page is its own address).
void openDevPage(DevPage page) => openDevPageAt(page.path);

/// Opens [path] (an address on this site) in this tab.
void openDevPageAt(String path) =>
    launchUrl(Uri.base.resolve(path), webOnlyWindowName: '_self');

/// The pages as a row of links; [current] is highlighted and inert.
class DevNavBar extends StatelessWidget {
  const DevNavBar({super.key, required this.current, this.onOpen});
  final DevPage current;

  /// Opens a page (tests replace it); defaults to [openDevPage].
  final void Function(DevPage page)? onOpen;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    alignment: WrapAlignment.center,
    children: [
      for (final p in DevPage.values)
        TextButton.icon(
          key: ValueKey('dev-nav-${p.name}'),
          style: TextButton.styleFrom(
            foregroundColor: p == current ? _ink : _mint,
            backgroundColor: p == current ? _mint : null,
            shape: const RoundedRectangleBorder(),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: p == current ? null : () => (onOpen ?? openDevPage)(p),
          icon: Icon(p.icon, size: 15),
          label: Text(
            p.label,
            style: const TextStyle(fontSize: 11, letterSpacing: 2),
          ),
        ),
    ],
  );
}

/// The footer of every dev page: the page's source and the build version.
class DevFooter extends StatelessWidget {
  const DevFooter({super.key, required this.page});
  final DevPage page;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${page.label} · ${page.path}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              color: _dim,
            ),
          ),
        ),
        // --- build-version: the one slot for the build version label.
        const KeyedSubtree(
          key: ValueKey('dev-footer-version'),
          child: BuildVersionLabel(),
        ),
      ],
    ),
  );
}
