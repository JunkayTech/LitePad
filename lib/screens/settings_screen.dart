import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:docx_template/docx_template.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/note_service.dart';
import '../models/note.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode mode;
  final void Function(ThemeMode) onThemeChange;
  const SettingsScreen(
      {super.key, required this.mode, required this.onThemeChange});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _exportNoteId;
  String? _manageNoteId;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<NoteService?>(context);
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: Text('NoteService not available')),
      );
    }

    final notes = service.notes;
    final dropdownItems = notes
        .map((n) => DropdownMenuItem<String>(
              value: n.id,
              child:
                  Text(n.title, overflow: TextOverflow.ellipsis, maxLines: 1),
            ))
        .toList();

    if (_exportNoteId != null && notes.every((n) => n.id != _exportNoteId)) {
      _exportNoteId = null;
    }
    if (_manageNoteId != null && notes.every((n) => n.id != _manageNoteId)) {
      _manageNoteId = null;
    }

    Note? getNoteById(String? id) {
      if (id == null) return null;
      try {
        return service.getNoteById(id);
      } catch (_) {
        return null;
      }
    }

    final selectedExportNote = getNoteById(_exportNoteId);
    final selectedManageNote = getNoteById(_manageNoteId);

    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 80.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('settings_list'),
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          children: [
            // Theme
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(
                widget.mode == ThemeMode.system
                    ? 'System'
                    : widget.mode == ThemeMode.light
                        ? 'Light'
                        : 'Dark',
              ),
              trailing: PopupMenuButton<ThemeMode>(
                onSelected: widget.onThemeChange,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: ThemeMode.system, child: Text('System')),
                  PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
                  PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
            ),

            const Divider(),
            const Text('Export notes',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _exportNoteId,
              items: dropdownItems,
              isExpanded: true,
              onChanged: (id) => setState(() => _exportNoteId = id),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint:
                  Text(notes.isEmpty ? 'No notes available' : 'Choose a note'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // EXPORT: Save to app storage, then share
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (selectedExportNote == null)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final title = selectedExportNote!.title;
                              final body = selectedExportNote!.content ?? '';
                              final content = '$title\n\n$body';

                              // Choose format
                              final format = await showModalBottomSheet<String>(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.text_snippet),
                                        title: const Text('Save as TXT'),
                                        onTap: () =>
                                            Navigator.of(ctx).pop('txt'),
                                      ),
                                      ListTile(
                                        leading:
                                            const Icon(Icons.picture_as_pdf),
                                        title: const Text('Save as PDF'),
                                        onTap: () =>
                                            Navigator.of(ctx).pop('pdf'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.description),
                                        title: const Text('Save as DOCX'),
                                        onTap: () =>
                                            Navigator.of(ctx).pop('docx'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.close),
                                        title: const Text('Cancel'),
                                        onTap: () =>
                                            Navigator.of(ctx).pop(null),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (format == null) return;

                              final safeBase = title.replaceAll(
                                  RegExp(r'[<>:"/\\|?*\n\r]+'), '_');

                              // Save into app's documents directory
                              final dir =
                                  await getApplicationDocumentsDirectory();
                              final filePath = '${dir.path}/$safeBase.$format';
                              final file = File(filePath);

                              if (format == 'txt') {
                                await file.writeAsString(content, flush: true);
                              } else if (format == 'pdf') {
                                final pdfDoc = pw.Document();
                                pdfDoc.addPage(
                                  pw.MultiPage(
                                    build: (ctx) => [
                                      pw.Text(
                                        safeBase,
                                        style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(height: 12),
                                      pw.Text(content),
                                    ],
                                  ),
                                );
                                final bytes = await pdfDoc.save();
                                await file.writeAsBytes(bytes, flush: true);
                              } else {
                                try {
                                  final bytes = await rootBundle.load(
                                      'assets/templates/summary_template.docx');
                                  final template = await DocxTemplate.fromBytes(
                                      bytes.buffer.asUint8List());

                                  final now = DateTime.now();
                                  final formattedDate =
                                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                                  final c = Content()
                                    ..add(TextContent('title', safeBase))
                                    ..add(TextContent('date', formattedDate))
                                    ..add(
                                        TextContent('content', content.trim()));

                                  final generated = await template.generate(c);
                                  await file.writeAsBytes(generated!,
                                      flush: true);
                                } catch (e) {
                                  debugPrint(
                                      'DOCX generation failed: $e — falling back to TXT');
                                  await file.writeAsString(content,
                                      flush: true);
                                }
                              }

                              // Share the file so the user can move/save it wherever they want
                              await Share.shareXFiles(
                                [XFile(file.path)],
                                text: 'Exported note',
                                subject: safeBase,
                              );

                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Saved to app storage: $filePath')),
                              );
                            } catch (e, st) {
                              debugPrint('Export error: $e\n$st');
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Export failed')));
                            }
                          },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export'),
                  ),
                ),
                const SizedBox(width: 12),
                // SHARE: system share sheet (raw text)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (selectedExportNote == null)
                        ? null
                        : () async {
                            final title = selectedExportNote!.title;
                            final body = selectedExportNote!.content ?? '';
                            final content = '$title\n\n$body';
                            try {
                              await Share.share(content, subject: title);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Share failed')));
                            }
                          },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const Text('Manage notes',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _manageNoteId,
              items: dropdownItems,
              isExpanded: true,
              onChanged: (id) => setState(() => _manageNoteId = id),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint:
                  Text(notes.isEmpty ? 'No notes available' : 'Choose a note'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (selectedManageNote == null)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (selectedManageNote!.locked) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Note is locked')));
                              return;
                            }
                            try {
                              await service.deleteNote(selectedManageNote.id);
                              setState(() {
                                _manageNoteId = null;
                                if (_exportNoteId == selectedManageNote.id) {
                                  _exportNoteId = null;
                                }
                              });
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Note deleted')));
                            } catch (e, st) {
                              debugPrint('Delete error: $e\n$st');
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Delete failed')));
                            }
                          },
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (selectedManageNote == null)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final newLocked = !(selectedManageNote!.locked);
                              await service.setNoteLocked(
                                  selectedManageNote.id, newLocked);
                              setState(() {
                                _manageNoteId = selectedManageNote.id;
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(newLocked
                                        ? 'Note locked'
                                        : 'Note unlocked')),
                              );
                            } catch (e, st) {
                              debugPrint('Lock toggle error: $e\n$st');
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Operation failed')));
                            }
                          },
                    icon: Icon(
                      selectedManageNote?.locked == true
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                    ),
                    label: Text(
                        selectedManageNote?.locked == true ? 'Unlock' : 'Lock'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // Delete all notes
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: Colors.redAccent),
              title: const Text('Delete all notes',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text(
                  'This will permanently remove all notes from the app storage.'),
              onTap: notes.isEmpty
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete all notes'),
                          content: const Text(
                              'Are you sure you want to permanently delete all notes?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete all',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await service.clearAll();
                          setState(() {
                            _selectedReset();
                          });
                          messenger.showSnackBar(const SnackBar(
                              content: Text('All notes deleted')));
                        } catch (e, st) {
                          debugPrint('Clear all error: $e\n$st');
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Operation failed')));
                        }
                      }
                    },
            ),

            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('App and developer info'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _selectedReset() {
    _exportNoteId = null;
    _manageNoteId = null;
  }
}
