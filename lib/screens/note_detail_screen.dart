import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import 'note_editor_screen.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggleRead(Note note) async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    final text = '${note.title}\n\n${note.content}';
    if (text.trim().isEmpty) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.speak(text);
  }

  /// Parse content and replace <image:n> markers with actual images
  List<Widget> _parseContent(
      String content, List<String> imagePaths, TextStyle? textStyle) {
    final widgets = <Widget>[];
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.startsWith('<image:')) {
        final index = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (index != null && index >= 0 && index < imagePaths.length) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.file(
                File(imagePaths[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          widgets.add(Text(line, style: textStyle));
        }
      } else if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8)); // preserve blank lines
      } else {
        widgets.add(Text(line, style: textStyle));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<NoteService>(context);
    final note = service.getNoteById(widget.noteId);

    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: const Center(child: Text('Note not found')),
      );
    }

    if (note.locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Locked Note')),
        body: const Center(
          child: Text(
            'This note is locked and cannot be viewed or edited',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bodyStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16);

    return Scaffold(
      appBar: AppBar(
        // 👇 Speaker only visible if note is not locked
        leading: note.locked
            ? null
            : IconButton(
                icon: Icon(_isSpeaking
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded),
                tooltip:
                    _isSpeaking ? 'Stop automated reader' : 'Automated reader',
                onPressed: () => _toggleRead(note),
              ),
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!note.locked) // 👈 only allow editing if not locked
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit note',
              onPressed: () async {
                final updated = await Navigator.of(context).push<Note?>(
                  MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(note: note),
                  ),
                );
                if (updated != null) {
                  await service.updateNote(updated);
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Updated: ${note.updatedAt.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // 👇 Inline content rendering (text + gallery/camera images)
                ..._parseContent(note.content, note.imagePaths, bodyStyle),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
