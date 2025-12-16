import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/note.dart';
import '../screens/note_detail_screen.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  const NoteCard({super.key, required this.note});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _tts.setStartHandler(() {
      if (mounted) setState(() => _speaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final text = widget.note.content.trim();
    if (text.isEmpty) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            Container(
                width: 6,
                height: 56,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(note.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis)),
                      if (note.locked)
                        const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.lock_rounded, size: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content.split('\n').first,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatDate(note.updatedAt),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_speaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded),
                        onPressed: _toggleSpeak,
                        tooltip: _speaking ? 'Stop' : 'Read aloud',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0)
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
