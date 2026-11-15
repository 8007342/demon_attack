// pwa-install: the title page's one-click "install as an app" toast.
//
// It appears only while the browser itself offers a one-click install (a
// deferred `beforeinstallprompt`, see web/install_bridge.js): its INSTALL
// button opens the browser's own approval dialog directly. Where installing
// needs manual steps (Safari on iOS and macOS, Firefox) it never appears,
// and there are no instructions or links anywhere. Closing it (or declining
// the browser's dialog) snoozes it for [InstallToastPolicy.snooze].
import 'package:flutter/material.dart';

import '../game/scene.dart' show mint;
import '../services/install_prompt.dart';
import '../services/run_storage.dart' show LocalStore;

/// When the toast may show (pure, so tests can drive it with a clock).
class InstallToastPolicy {
  InstallToastPolicy(this.store, {this.now = DateTime.now});

  /// Where the last dismissal is remembered, per viewer (localStorage on the
  /// web). Every read and write tolerates a store that throws.
  final LocalStore store;
  final DateTime Function() now;

  static const dismissedKey = 'demonAttack.installDismissedAt';

  /// How long a dismissal holds before the toast may ask once more.
  static const snooze = Duration(days: 90);

  /// Read from the store once per page view (the title rebuilds per frame).
  late DateTime? dismissedAt = _load();

  DateTime? _load() {
    try {
      final raw = store.read(dismissedKey);
      final millis = raw == null ? null : int.tryParse(raw);
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  bool get snoozed {
    final at = dismissedAt;
    if (at == null) return false;
    final since = now().toUtc().difference(at);
    // A clock set back before the dismissal still counts as snoozed.
    return since < snooze && since > -snooze;
  }

  void rememberDismissal() {
    final at = now().toUtc();
    dismissedAt = at;
    try {
      store.write(dismissedKey, at.millisecondsSinceEpoch.toString());
    } catch (_) {}
  }

  bool shows(InstallPrompt prompt) =>
      prompt.available && !prompt.installed && !snoozed;
}

/// The toast itself: one line, an INSTALL button and a close ✕, styled
/// like the radio toasts (rounded card, soft shadow, mint accent bar).
class InstallToast extends StatefulWidget {
  const InstallToast({super.key, required this.prompt, required this.policy});
  final InstallPrompt prompt;
  final InstallToastPolicy policy;

  @override
  State<InstallToast> createState() => _InstallToastState();
}

class _InstallToastState extends State<InstallToast> {
  /// Closed, answered or failed in this page view: never back until reload.
  bool _done = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    widget.prompt.addListener(_changed);
  }

  @override
  void didUpdateWidget(InstallToast old) {
    super.didUpdateWidget(old);
    if (old.prompt != widget.prompt) {
      old.prompt.removeListener(_changed);
      widget.prompt.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.prompt.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _close() {
    widget.policy.rememberDismissal();
    setState(() => _done = true);
  }

  Future<void> _install() async {
    if (_asking) return;
    setState(() => _asking = true);
    final outcome = await widget.prompt.prompt();
    // Declining the browser's own dialog counts as "not now".
    if (outcome == InstallOutcome.dismissed) widget.policy.rememberDismissal();
    if (mounted) {
      setState(() {
        _asking = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = !_done && (_asking || widget.policy.shows(widget.prompt));
    if (!visible) return const SizedBox.shrink();
    const radius = 8.0, bar = 3.0;
    return Semantics(
      container: true,
      label: 'Install Demon Attack as an app',
      child: Container(
        key: const ValueKey('install-toast'),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6121D2E), Color(0xD90A1220)],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0x6694A3B8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(bar + 10, 2, 2, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'PLAY IT AS AN APP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFD7E5EF),
                          fontSize: 10,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const ValueKey('install-toast-install'),
                      onPressed: _asking ? null : _install,
                      style: TextButton.styleFrom(
                        foregroundColor: mint,
                        minimumSize: const Size(64, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                      child: const Text('INSTALL'),
                    ),
                    IconButton(
                      key: const ValueKey('install-toast-close'),
                      tooltip: 'Dismiss',
                      onPressed: _close,
                      iconSize: 16,
                      color: const Color(0xFF8D9EB3),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: bar,
                child: ColoredBox(color: mint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
