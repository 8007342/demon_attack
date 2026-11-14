/// A notes button for a whole page (/console, a /gallery page). It opens the
/// same notes panel as the asset studio, in a dialog, on one store: notes
/// written on any page live in browser storage under one key, so the studio,
/// the gallery and the console all see them, and they outlive a reload.
///
/// "Copy for an agent" puts every note on the clipboard as a markdown
/// worklist (ReviewNotesStore.worklistMarkdown) to paste into a chat;
/// "Save .md" downloads the same text.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notes_panel.dart';
import 'review_notes.dart';
import 'review_platform.dart';

/// Copies every note as a markdown worklist; returns a status line.
Future<String> copyWorklist(ReviewNotesStore store) async {
  store.refresh();
  await Clipboard.setData(ClipboardData(text: store.worklistMarkdown()));
  final n = store.count;
  return 'Copied $n note${n == 1 ? '' : 's'} as markdown: paste it to an agent';
}

/// Downloads every note as a markdown worklist; returns a status line.
String saveWorklist(ReviewNotesStore store) {
  store.refresh();
  store.platform.download(
    store.worklistFilename,
    store.worklistMarkdown(),
    type: 'text/markdown',
  );
  return 'Saved ${store.worklistFilename}';
}

/// A floating "NOTES" button for [asset] (kind page or scene). Put it in a
/// Stack over the page.
class PageNotesButton extends StatefulWidget {
  const PageNotesButton({super.key, required this.asset, this.store});
  final ReviewAsset asset;

  /// Injected in tests; otherwise one store on the browser's storage.
  final ReviewNotesStore? store;

  @override
  State<PageNotesButton> createState() => _PageNotesButtonState();
}

class _PageNotesButtonState extends State<PageNotesButton> {
  late final ReviewNotesStore store =
      widget.store ?? ReviewNotesStore(createReviewPlatform());

  Future<void> _open() async {
    store.refresh();
    await showDialog<void>(
      context: context,
      builder: (context) => PageNotesDialog(asset: widget.asset, store: store),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final here = store.notesFor(widget.asset.ref).length;
        return Tooltip(
          message: 'Notes on this page (kept in this browser)',
          child: FilledButton.tonalIcon(
            key: const ValueKey('page-notes'),
            style: FilledButton.styleFrom(
              backgroundColor: studioPanel.withValues(alpha: .92),
              foregroundColor: studioMint,
              side: const BorderSide(color: studioLine),
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _open,
            icon: const Icon(Icons.edit_note, size: 18),
            label: Text(
              here == 0 ? 'NOTES' : 'NOTES ($here)',
              style: const TextStyle(fontSize: 11, letterSpacing: 2),
            ),
          ),
        );
      },
    );
  }
}

/// The notes panel for one page, with the worklist copy and save.
class PageNotesDialog extends StatefulWidget {
  const PageNotesDialog({super.key, required this.asset, required this.store});
  final ReviewAsset asset;
  final ReviewNotesStore store;

  @override
  State<PageNotesDialog> createState() => _PageNotesDialogState();
}

class _PageNotesDialogState extends State<PageNotesDialog> {
  final _link = PlayheadLink();
  String status = '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: studioMint,
          brightness: Brightness.dark,
        ),
      ),
      child: Dialog(
        backgroundColor: studioInk,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: studioLine),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 560,
          height: (size.height - 32).clamp(320, 680).toDouble(),
          child: Column(
            children: [
              Expanded(
                child: NotesPanel(
                  asset: widget.asset,
                  store: widget.store,
                  link: _link,
                ),
              ),
              const Divider(color: studioLine, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  status.isNotEmpty
                      ? status
                      : '${widget.store.count} notes in this browser '
                            '(studio, gallery and console together)',
                  style: const TextStyle(color: studioDim, fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('notes-copy'),
                      onPressed: () async {
                        final s = await copyWorklist(widget.store);
                        if (mounted) setState(() => status = s);
                      },
                      icon: const Icon(Icons.content_copy, size: 16),
                      label: const Text('Copy for an agent'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('notes-save'),
                      onPressed: () =>
                          setState(() => status = saveWorklist(widget.store)),
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('Save .md'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
