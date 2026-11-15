import 'package:flutter/foundation.dart';

/// What the player chose in the browser's own install dialog.
enum InstallOutcome { accepted, dismissed, unavailable }

/// The browser's one-click install offer (pwa-install).
///
/// [available] is true only while the browser holds a deferred
/// `beforeinstallprompt`: one call to [prompt] then opens the browser's own
/// install approval. Browsers that need manual steps (Safari, Firefox) never
/// make it available. Listeners hear every change.
abstract class InstallPrompt extends ChangeNotifier {
  bool get available;

  /// Running as an installed app (display-mode standalone) or installed in
  /// this session (`appinstalled`).
  bool get installed;

  Future<InstallOutcome> prompt();
}

/// Never offers anything (non-web platforms and tests).
class NoInstallPrompt extends InstallPrompt {
  @override
  bool get available => false;
  @override
  bool get installed => false;
  @override
  Future<InstallOutcome> prompt() async => InstallOutcome.unavailable;
}
