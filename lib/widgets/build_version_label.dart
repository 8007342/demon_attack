// build-version: the build's version in small text, so the operator can tell
// which deploy is live (openspec/changes/build-version). One shared look for
// the title, the pause menu, /console, /gallery and /studio.
import 'package:flutter/material.dart';

import '../build_info.dart';

/// The version line: small, dim, unobtrusive; never takes pointer input.
class BuildVersionLabel extends StatelessWidget {
  const BuildVersionLabel({super.key, this.version});

  /// Overrides the build's version (tests).
  final String? version;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Text(
      version ?? buildVersion(),
      key: const ValueKey('build-version'),
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1,
        fontFamily: 'monospace',
        color: Color(0x8894A6B8),
        decoration: TextDecoration.none,
      ),
    ),
  );
}

/// A footer that puts [BuildVersionLabel] in a page's bottom-left corner:
/// `MaterialApp(builder: withBuildVersion)` for a whole app.
Widget withBuildVersion(BuildContext context, Widget? child) => Stack(
  textDirection: TextDirection.ltr,
  children: [
    ?child,
    const Positioned(left: 6, bottom: 4, child: BuildVersionLabel()),
  ],
);

/// The title screen's corner: [BuildVersionLabel] at the bottom left of a
/// [Stack].
class BuildVersionCorner extends StatelessWidget {
  const BuildVersionCorner({super.key});

  @override
  Widget build(BuildContext context) =>
      const Positioned(left: 6, bottom: 4, child: BuildVersionLabel());
}

/// A page footer (`Scaffold.bottomNavigationBar`): [BuildVersionLabel] on a
/// line of its own, bottom left.
class BuildVersionFooter extends StatelessWidget {
  const BuildVersionFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Align(
      alignment: Alignment.bottomLeft,
      heightFactor: 1,
      child: BuildVersionLabel(),
    ),
  );
}
