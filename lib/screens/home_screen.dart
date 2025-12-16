import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/note_service.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import '../screens/edit_note_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showGrid = false;
  String _query = '';
  SortMode _sortMode = SortMode.recent;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Note> _applyFilters(List<Note> notes) {
    final filtered = List<Note>.from(notes);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered.retainWhere((n) =>
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q));
    }

    filtered.sort((a, b) {
      final lockedA = a.locked ? 1 : 0;
      final lockedB = b.locked ? 1 : 0;
      if (lockedA != lockedB) return lockedB - lockedA;
      if (_sortMode == SortMode.recent) {
        return b.updatedAt.compareTo(a.updatedAt);
      } else {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return filtered;
  }

  void _openQuickNote() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _QuickNoteSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<NoteService>(context);
    final notes = _applyFilters(service.notes);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && notes.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
        appBar: AppBar(
          title: const Text('LiteNotes'),
          centerTitle: false,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_showGrid
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded),
              tooltip: _showGrid ? 'Grid view' : 'List view',
              onPressed: () => setState(() => _showGrid = !_showGrid),
            ),
            PopupMenuButton<SortMode>(
              onSelected: (m) => setState(() => _sortMode = m),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: SortMode.recent, child: Text('Sort by recent')),
                PopupMenuItem(
                    value: SortMode.title, child: Text('Sort by title')),
              ],
              icon: const Icon(Icons.sort_rounded),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search notes',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // FAB placed bottom-right above nav bar
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 70.0, right: 12.0),
          child: FloatingActionButton.small(
            onPressed: _openQuickNote,
            tooltip: 'New note',
            elevation: 6,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded),
          ),
        ),
        body: notes.isEmpty
            ? const _EmptyState()
            : _showGrid
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) => NoteCard(note: notes[i]),
                    ),
                  )
                : ListView.separated(
                    controller:
                        _scrollController, // 👈 attach scroll controller
                    padding: const EdgeInsets.only(
                        top: 8, bottom: 40), // 👈 space below last note
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (ctx, i) {
                      final note = notes[i];
                      return GestureDetector(
                        onTap: () {
                          if (note.locked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'This note is locked and cannot be viewed or edited'),
                              ),
                            );
                            return; // 👈 block navigation
                          }
                          // Navigate to detail/edit screen if not locked
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => EditNoteScreen(note: note)),
                          );
                        },
                        child: Dismissible(
                          key: ValueKey(note.id),
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.push_pin_rounded,
                                color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await Provider.of<NoteService>(context,
                                      listen: false)
                                  .setNoteLocked(note.id, !note.locked);
                              return false;
                            } else {
                              if (note.locked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Note is locked')),
                                );
                                return false;
                              }
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete note'),
                                  content: Text('Delete "${note.title}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await Provider.of<NoteService>(context,
                                        listen: false)
                                    .deleteNote(note.id);
                                return true;
                              }
                              return false;
                            }
                          },
                          child: NoteCard(note: note),
                        ),
                      );
                    },
                  ));
  }
}

enum SortMode { recent, title }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_rounded, size: 84, color: primary),
            const SizedBox(height: 16),
            const Text('No notes yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap the + button to create your first note',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _QuickNoteSheet extends StatefulWidget {
  const _QuickNoteSheet();

  @override
  State<_QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends State<_QuickNoteSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  late final stt.SpeechToText _speech;
  bool _listening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        // Auto-restart after silence if still in listening mode
        if (status == 'done' && _listening) {
          _startListening();
        }
      },
      onError: (error) {
        debugPrint("Speech error: $error");
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        if (r.recognizedWords.isEmpty) return;
        if (r.finalResult) {
          // Append recognized words to existing content
          final existing = _content.text;
          final separator = existing.isEmpty ||
                  existing.endsWith(' ') ||
                  existing.endsWith('\n')
              ? ''
              : ' ';
          _content.text = '$existing$separator${r.recognizedWords}';
          _content.selection = TextSelection.fromPosition(
            TextPosition(offset: _content.text.length),
          );
        }
      },
      partialResults: true,
      // Optional: choose a mode suitable for dictation; fallback if not available
      // listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _toggleListen() async {
    if (!_speechAvailable) return;
    if (!_listening) {
      await _startListening();
    } else {
      setState(() => _listening = false);
      await _speech.stop();
    }
  }

  void _save() {
    final content = _content.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save empty note')));
      return;
    }
    final title = _title.text.trim().isEmpty
        ? _content.text.split('\n').first
        : _title.text.trim();
    Provider.of<NoteService>(context, listen: false).addNote(title, content);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Note saved')));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              TextField(
                  controller: _title,
                  decoration:
                      const InputDecoration(hintText: 'Title (optional)')),
              const SizedBox(height: 8),
              TextField(
                  controller: _content,
                  maxLines: 6,
                  decoration: const InputDecoration(
                      hintText: 'Type or dictate your note...')),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(_listening
                        ? Icons.stop_circle_rounded
                        : Icons.mic_rounded),
                    onPressed: _speechAvailable ? _toggleListen : null,
                  ),
                  const Spacer(),
                  TextButton(
                      onPressed: () {
                        _title.clear();
                        _content.clear();
                      },
                      child: const Text('Clear')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
