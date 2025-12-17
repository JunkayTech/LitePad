import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note note;
  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();
  final List<String> _images = []; // store image paths

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _images.addAll(widget.note.imagePaths); // preload existing images if any
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _images.add(picked.path);
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Note cannot be empty')));
      return;
    }

    setState(() => _saving = true);

    final updated = widget.note.copyWith(
      title: title.isEmpty ? widget.note.title : title,
      content: content,
      imagePaths: _images,
      updatedAt: DateTime.now(),
    );

    try {
      await Provider.of<NoteService>(context, listen: false)
          .updateNote(updated);
      Navigator.of(context).pop(updated);
    } catch (e, st) {
      debugPrint('Save note failed: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to save note')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.image),
            tooltip: 'Insert image',
            onSelected: (choice) {
              if (choice == 'gallery') {
                _pickImage(ImageSource.gallery);
              } else if (choice == 'camera') {
                _pickImage(ImageSource.camera);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'gallery', child: Text('From Gallery')),
              const PopupMenuItem(value: 'camera', child: Text('From Camera')),
            ],
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: false,
                      decoration: const InputDecoration(
                        hintText: 'Write your note here...',
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._images.map((path) => Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Delete image',
                              onPressed: () {
                                setState(() {
                                  _images.remove(path);
                                });
                              },
                            ),
                          ],
                        )),
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
