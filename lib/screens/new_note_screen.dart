import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';

class NewNoteScreen extends StatefulWidget {
  const NewNoteScreen({super.key});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

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
        title: const Text('New note'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check_rounded),
            onPressed: () async {
              final service = Provider.of<NoteService>(context, listen: false);
              await service.addNote(_titleCtrl.text, _contentCtrl.text);
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
                hint: 'Start typing your thoughts...',
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AnimatedFab(
        icon: Icons.check_rounded,
        label: 'Save note',
        color: scheme.primary,
        onTap: () async {
          final service = Provider.of<NoteService>(context, listen: false);
          await service.addNote(_titleCtrl.text, _contentCtrl.text);
          if (mounted) Navigator.pop(context);
        },
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

class _AnimatedFab extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedFab(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FloatingActionButton.extended(
        heroTag: 'fab_save',
        onPressed: widget.onTap,
        icon: Icon(widget.icon),
        label: Text(widget.label),
        backgroundColor: widget.color,
      ),
    );
  }
}
