import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_template/docx_template.dart';
import '../services/note_service.dart';
import '../utils/share_utils.dart';

enum SummaryMode { offline, ai }

class SummarizerScreen extends StatefulWidget {
  const SummarizerScreen({super.key});

  @override
  State<SummarizerScreen> createState() => _SummarizerScreenState();
}

class _SummarizerScreenState extends State<SummarizerScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _summary = "";
  int _sentences = 1;
  SummaryMode _mode = SummaryMode.offline;

  late final FlutterTts _tts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((err) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _tts.stop();
    try {
      _scrollController.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _summarize() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to summarize')),
      );
      return;
    }

    if (_mode == SummaryMode.ai) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Unavailable'),
          content: const Text(
            'Smart AI summarization is not available in this build. '
            'This feature is coming soon. For now, use the Quick Offline summarizer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _mode = SummaryMode.offline);
                Navigator.of(ctx).pop();
              },
              child: const Text('Use Offline'),
            ),
          ],
        ),
      );
      return;
    }

    final summarySentences =
        _extractSummaryTuned(text, sentenceCount: _sentences);
    setState(() => _summary = summarySentences.join(" "));

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    try {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  List<String> _extractSummaryTuned(String text, {int sentenceCount = 1}) {
    final sentenceRegex = RegExp(r'(?<=[.!?])\s+');
    final rawSentences = text
        .split(sentenceRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawSentences.isEmpty) return <String>[];
    if (sentenceCount >= rawSentences.length) return rawSentences;

    final wordRegex = RegExp(r"[A-Za-z0-9']+");
    final stopwords = <String>{
      'a',
      'about',
      'above',
      'after',
      'again',
      'against',
      'all',
      'am',
      'an',
      'and',
      'any',
      'are',
      'as',
      'at',
      'be',
      'because',
      'been',
      'before',
      'being',
      'below',
      'between',
      'both',
      'but',
      'by',
      'can',
      'cannot',
      'could',
      'did',
      'do',
      'does',
      'doing',
      'down',
      'during',
      'each',
      'few',
      'for',
      'from',
      'further',
      'had',
      'has',
      'have',
      'having',
      'he',
      'her',
      'here',
      'hers',
      'him',
      'his',
      'how',
      'i',
      'if',
      'in',
      'into',
      'is',
      'it',
      'its',
      'itself',
      'me',
      'more',
      'most',
      'my',
      'myself',
      'no',
      'nor',
      'not',
      'of',
      'off',
      'on',
      'once',
      'only',
      'or',
      'other',
      'our',
      'ours',
      'out',
      'over',
      'own',
      'same',
      'she',
      'should',
      'so',
      'some',
      'such',
      'than',
      'that',
      'the',
      'their',
      'them',
      'then',
      'there',
      'these',
      'they',
      'this',
      'those',
      'through',
      'to',
      'too',
      'under',
      'until',
      'up',
      'very',
      'was',
      'we',
      'were',
      'what',
      'when',
      'where',
      'which',
      'while',
      'who',
      'why',
      'with',
      'you',
      'your'
    };

    final freq = <String, double>{};
    for (final sentence in rawSentences) {
      for (final match in wordRegex.allMatches(sentence)) {
        final w = match.group(0)!.toLowerCase();
        if (w.length <= 2 || stopwords.contains(w)) continue;
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return rawSentences.take(sentenceCount).toList();
    final maxFreq = freq.values.reduce((a, b) => a > b ? a : b);
    final normalized = freq.map((k, v) => MapEntry(k, v / maxFreq));

    final firstSentenceWords = rawSentences.isNotEmpty
        ? rawSentences[0]
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList()
        : <String>[];

    final scores = <int, double>{};
    for (var i = 0; i < rawSentences.length; i++) {
      final sentence = rawSentences[i];
      double score = 0;
      int wordCount = 0;
      final words = <String>[];
      for (final match in wordRegex.allMatches(sentence)) {
        final w = match.group(0)!.toLowerCase();
        if (w.length <= 2 || stopwords.contains(w)) continue;
        wordCount++;
        words.add(w);
        score += (normalized[w] ?? 0);
      }

      if (wordCount < 5) score *= 0.5;
      if (wordCount > 30) score *= 0.75;

      final positionBonus = 1.0 - (i / rawSentences.length) * 0.2;
      score *= positionBonus;

      final overlap = words.where((w) => firstSentenceWords.contains(w)).length;
      if (overlap > 0) score += overlap * 0.18;

      final capitalizedCount =
          RegExp(r'\b[A-Z][a-z]{2,}\b').allMatches(sentence).length;
      if (capitalizedCount > 0) score += 0.08 * capitalizedCount;

      if (wordCount > 0) score = score / math.pow(wordCount.toDouble(), 0.05);

      scores[i] = score;
    }

    final sortedIndices = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    final selected = <int>[];
    for (final idx in sortedIndices) {
      final candidateWords = rawSentences[idx]
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      bool tooSimilar = selected.any((sel) {
        final otherWords = rawSentences[sel]
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toSet();
        if (candidateWords.isEmpty) return true;
        final overlap = candidateWords.where(otherWords.contains).length;
        return overlap / candidateWords.length > 0.6;
      });
      if (!tooSimilar) selected.add(idx);
      if (selected.length >= sentenceCount) break;
    }

    if (selected.length < sentenceCount) {
      for (final idx in sortedIndices) {
        if (selected.contains(idx)) continue;
        selected.add(idx);
        if (selected.length >= sentenceCount) break;
      }
    }

    selected.sort();
    return selected.map((i) => rawSentences[i]).toList();
  }

  Future<void> _onSharePressed() async {
    if (_summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share')),
      );
      return;
    }
    await ShareUtils.showShareOptions(context, _summary,
        subject: "My LitePad Summary");
  }

  Future<void> _saveSummary() async {
    if (_summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save')),
      );
      return;
    }

    final service = context.read<NoteService>();
    String title;
    if (_titleCtrl.text.trim().isNotEmpty) {
      title = _titleCtrl.text.trim();
    } else {
      final autoTitle = generateTitleFromText(
          _summary.isNotEmpty ? _summary : _textCtrl.text);
      title = autoTitle;
    }

    service.addNote(title, _summary);
    _titleCtrl.clear();
    _textCtrl.clear();
    setState(() => _summary = "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: $title')),
    );
  }

  void _clearFields() {
    _titleCtrl.clear();
    _textCtrl.clear();
    setState(() => _summary = "");
  }

  Future<void> _speakSummary() async {
    if (_summary.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(_summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS error: $e')),
        );
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Summarizer Pad")),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: _clearFields,
          child: const Icon(Icons.clear),
          tooltip: 'New summary',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: _scrollController,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Optional Title (auto-generated if empty)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: "Paste or type a long note...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Mode: "),
                const SizedBox(width: 8),
                DropdownButton<SummaryMode>(
                  value: _mode,
                  items: const [
                    DropdownMenuItem(
                        value: SummaryMode.offline,
                        child: Text("Quick Offline")),
                    DropdownMenuItem(
                        value: SummaryMode.ai, child: Text("Smart AI")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _mode = val);
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  _mode == SummaryMode.offline
                      ? "Offline (fast)"
                      : "AI (coming soon)",
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Number of sentences: "),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _sentences,
                  items: List.generate(10, (i) => i + 1)
                      .map((num) => DropdownMenuItem(
                          value: num, child: Text(num.toString())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _sentences = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _summarize,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("Summarize"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveSummary,
                  icon: const Icon(Icons.save),
                  label: const Text("Save"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            if (_summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceVariant,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "✨ Your $_sentences‑sentence summary (${_mode == SummaryMode.offline ? "Offline" : "AI"}):",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: SingleChildScrollView(
                            child: Text(_summary,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text("Copy"),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _summary));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Summary copied to clipboard')));
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.volume_up),
                                label: const Text("Speak"),
                                onPressed: _isSpeaking ? null : _speakSummary,
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.stop),
                                label: const Text("Stop"),
                                onPressed: _isSpeaking ? _stopSpeaking : null,
                              ),
                            ]),
                      ]),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

String generateTitleFromText(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 'Untitled';

  final sentenceRegex = RegExp(r'(?<=[.!?])\s+');
  final sentences = cleaned
      .split(sentenceRegex)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (sentences.isNotEmpty) {
    final first = sentences[0];
    final words =
        first.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= 8 && words.length >= 3) {
      final candidate = words.join(' ');
      return _titleCase(_stripTrailingPunctuation(candidate));
    }
  }

  final wordRegex = RegExp(r"[A-Za-z0-9']+");
  final stopwords = <String>{
    'a',
    'about',
    'above',
    'after',
    'again',
    'against',
    'all',
    'am',
    'an',
    'and',
    'any',
    'are',
    'as',
    'at',
    'be',
    'because',
    'been',
    'before',
    'being',
    'below',
    'between',
    'both',
    'but',
    'by',
    'can',
    'cannot',
    'could',
    'did',
    'do',
    'does',
    'doing',
    'down',
    'during',
    'each',
    'few',
    'for',
    'from',
    'further',
    'had',
    'has',
    'have',
    'having',
    'he',
    'her',
    'here',
    'hers',
    'him',
    'his',
    'how',
    'i',
    'if',
    'in',
    'into',
    'is',
    'it',
    'its',
    'itself',
    'me',
    'more',
    'most',
    'my',
    'myself',
    'no',
    'nor',
    'not',
    'of',
    'off',
    'on',
    'once',
    'only',
    'or',
    'other',
    'our',
    'ours',
    'out',
    'over',
    'own',
    'same',
    'she',
    'should',
    'so',
    'some',
    'such',
    'than',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'to',
    'too',
    'under',
    'until',
    'up',
    'very',
    'was',
    'we',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'who',
    'why',
    'with',
    'you',
    'your'
  };

  final freq = <String, int>{};
  for (final match in wordRegex.allMatches(cleaned)) {
    final w = match.group(0)!.toLowerCase();
    if (w.length <= 2) continue;
    if (stopwords.contains(w)) continue;
    freq[w] = (freq[w] ?? 0) + 1;
  }

  if (freq.isEmpty) {
    final fallback = cleaned.split(RegExp(r'\s+')).take(3).join(' ');
    return _titleCase(_stripTrailingPunctuation(fallback));
  }

  final keywords = freq.keys.toList()
    ..sort((a, b) {
      final cmp = freq[b]!.compareTo(freq[a]!);
      if (cmp != 0) return cmp;
      return b.length.compareTo(a.length);
    });

  final top = keywords.take(4).toList();
  final title = top.map((w) => w.replaceAll(RegExp(r'[_\-]'), ' ')).join(' ');
  return _titleCase(_stripTrailingPunctuation(title));
}

String _stripTrailingPunctuation(String s) {
  return s.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
}

String _titleCase(String s) {
  final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.map((w) {
    if (w.length <= 2) return w.toLowerCase();
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}
