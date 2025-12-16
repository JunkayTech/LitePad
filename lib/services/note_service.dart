import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NoteService extends ChangeNotifier {
  static const _prefsKey = 'litepad_notes';
  late SharedPreferences _prefs;
  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getStringList(_prefsKey) ?? [];
    final parsed = raw.map((e) => Note.fromJson(e)).toList();
    parsed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _notes
      ..clear()
      ..addAll(parsed);

    notifyListeners();
  }

  Future<void> _persist() async {
    final payload = _notes.map((n) => n.toJson()).toList();
    await _prefs.setStringList(_prefsKey, payload);
  }

  Future<void> addNote(String title, String content) async {
    final now = DateTime.now();
    final note = Note(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      content: content.trim(),
      createdAt: now,
      updatedAt: now,
      colorIndex: (now.millisecondsSinceEpoch ~/ 1000) % _accentColors.length,
      locked: false,
    );
    _notes.insert(0, note);
    await _persist();
    notifyListeners();
  }

  Future<void> updateNote(Note note, {String? title, String? content}) async {
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx == -1) return;

    final updated = note.copyWith(
      title: title ?? note.title,
      content: content ?? note.content,
      updatedAt: DateTime.now(),
    );

    _notes[idx] = updated;
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> setNoteLocked(String id, bool locked) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notes[idx] =
        _notes[idx].copyWith(locked: locked, updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Note? getNoteById(String id) =>
      _notes.firstWhere((n) => n.id == id, orElse: () => null as Note);

  Future<void> clearAll() async {
    _notes.clear();
    await _prefs.remove(_prefsKey);
    notifyListeners();
  }

  static const List<ColorHex> _accentColors = [
    ColorHex(0xFF6C72FF),
    ColorHex(0xFF3DD9D6),
    ColorHex(0xFFFF6584),
    ColorHex(0xFFFFC857),
    ColorHex(0xFF7BD88F),
  ];

  ColorHex accentFor(int index) => _accentColors[index % _accentColors.length];

  Color accentColorFor(int index) =>
      Color(accentFor(index).value).withValues(alpha: 1.0);

  Future<String> exportNoteToFile(Note note) async {
    final safeTitle = note.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final fileName = '${safeTitle}_${note.id}.txt';

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/LitePad_exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final file = File('${exportDir.path}/$fileName');
    final contents = StringBuffer()
      ..writeln('Title: ${note.title}')
      ..writeln('Created: ${note.createdAt.toIso8601String()}')
      ..writeln('Updated: ${note.updatedAt.toIso8601String()}')
      ..writeln('---')
      ..writeln(note.content);

    await file.writeAsString(contents.toString(), flush: true);
    return file.path;
  }
}

class ColorHex {
  final int value;
  const ColorHex(this.value);
}
