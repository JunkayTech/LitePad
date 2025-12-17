import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class EditNoteScreen extends StatefulWidget {
  final Note note;
  const EditNoteScreen({super.key, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.note.title);
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.note.content);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check_rounded),
            onPressed: () async {
              final service = Provider.of<NoteService>(context, listen: false);
              await service.updateNote(
                widget.note,
                title: _titleCtrl.text,
                content: _contentCtrl.text,
              );
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
        child: Column(
          children: [
            _GlassField(
              controller: _titleCtrl,
              hint: 'Title',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassField(
                controller: _contentCtrl,
                hint: 'Edit your note...',
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_edit',
        onPressed: () async {
          final service = Provider.of<NoteService>(context, listen: false);
          await service.updateNote(
            widget.note,
            title: _titleCtrl.text,
            content: _contentCtrl.text,
          );
          if (mounted) Navigator.pop(context);
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('Save changes'),
        backgroundColor: scheme.primary,
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextStyle? style;
  final int? maxLines;
  final bool expands;
  const _GlassField({
    required this.controller,
    required this.hint,
    this.style,
    this.maxLines,
    this.expands = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      expands: expands,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0x22171822) : const Color(0x22FFFFFF),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(18),
      ),
      style: style,
    );
  }
}
