import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../services/note_service.dart';

abstract class NoteBlock {}

class TextBlock extends NoteBlock {
  String text;
  TextBlock(this.text);
}

class ImageBlock extends NoteBlock {
  String path;
  ImageBlock(this.path);
}

class NoteEditorScreen extends StatefulWidget {
  final Note note;
  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();
  late List<NoteBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);

    // Initialize blocks from content + imagePaths
    _blocks = [];
    final lines = widget.note.content.split('\n');
    for (final line in lines) {
      if (line.startsWith('<image:')) {
        final index = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (index != null && index < widget.note.imagePaths.length) {
          _blocks.add(ImageBlock(widget.note.imagePaths[index]));
        }
      } else {
        _blocks.add(TextBlock(line));
      }
    }
    if (_blocks.isEmpty) _blocks.add(TextBlock(''));
  }

  Future<void> _insertImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        // Insert image at current position (after last focused text block)
        int insertIndex = _blocks.length;
        _blocks.add(ImageBlock(picked.path));
        // Add a new text block after image so user can continue writing
        _blocks.add(TextBlock(''));
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();

    // Collect text + images back into content + imagePaths
    final contentBuffer = StringBuffer();
    final imagePaths = <String>[];
    for (final block in _blocks) {
      if (block is TextBlock) {
        contentBuffer.writeln(block.text);
      } else if (block is ImageBlock) {
        final idx = imagePaths.length;
        imagePaths.add(block.path);
        contentBuffer.writeln('<image:$idx>');
      }
    }

    final content = contentBuffer.toString().trim();
    if (content.isEmpty && imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);

    final updated = widget.note.copyWith(
      title: title.isEmpty ? widget.note.title : title,
      content: content,
      imagePaths: imagePaths,
      updatedAt: DateTime.now(),
    );

    try {
      await Provider.of<NoteService>(context, listen: false)
          .updateNote(updated);
      Navigator.of(context).pop(updated);
    } catch (e, st) {
      debugPrint('Save note failed: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save note')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note.locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Locked Note')),
        body: const Center(
          child: Text('This note is locked and cannot be edited',
              style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.image),
            tooltip: 'Insert image',
            onSelected: (choice) {
              if (choice == 'gallery') {
                _insertImage(ImageSource.gallery);
              } else if (choice == 'camera') {
                _insertImage(ImageSource.camera);
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
                child: ListView.builder(
                  itemCount: _blocks.length,
                  itemBuilder: (ctx, i) {
                    final block = _blocks[i];
                    if (block is TextBlock) {
                      return TextField(
                        controller: TextEditingController(text: block.text),
                        onChanged: (val) => block.text = val,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Write here...',
                        ),
                      );
                    } else if (block is ImageBlock) {
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child:
                                Image.file(File(block.path), fit: BoxFit.cover),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Delete image',
                            onPressed: () {
                              setState(() {
                                _blocks.removeAt(i);
                              });
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
