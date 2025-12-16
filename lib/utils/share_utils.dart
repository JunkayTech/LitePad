import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:docx_template/docx_template.dart';

class ShareUtils {
  /// Shows a modal with share and save options for [contentText].
  static Future<void> showShareOptions(
    BuildContext context,
    String contentText, {
    String subject = "LitePad",
  }) async {
    if (contentText.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to share')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share via apps'),
              onTap: () {
                Navigator.of(ctx).pop();
                Share.share(contentText, subject: subject);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Save to device'),
              subtitle:
                  const Text('Save text as TXT, PDF, or DOCX (app documents)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _saveToAppDocuments(context, contentText, subject);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Always saves to the app documents directory (reliable for testing and devices).
  static Future<void> _saveToAppDocuments(
      BuildContext context, String content, String baseName) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Save as TXT'),
                onTap: () => Navigator.of(ctx).pop('txt')),
            ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Save as PDF'),
                onTap: () => Navigator.of(ctx).pop('pdf')),
            ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Save as DOCX'),
                onTap: () => Navigator.of(ctx).pop('docx')),
            ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(null)),
          ],
        ),
      ),
    );

    if (format == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving to app documents...')));

    try {
      final dir = await getApplicationDocumentsDirectory();
      final directoryPath = dir.path;
      final safeBase = baseName.replaceAll(RegExp(r'[<>:"/\\|?*\n\r]+'), '_');

      String savedPath;
      if (format == 'txt') {
        savedPath = await _saveAsTxt(directoryPath, safeBase, content);
      } else if (format == 'pdf') {
        savedPath = await _saveAsPdf(directoryPath, safeBase, content);
      } else {
        savedPath = await _saveAsDocx(directoryPath, safeBase, content);
      }

      debugPrint('Saved file at: $savedPath');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved: $savedPath')));
      }
    } catch (e, st) {
      debugPrint('Save failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  static Future<String> _saveAsTxt(
      String dirPath, String baseName, String content) async {
    final filename = '$baseName.txt';
    final file = File('${dirPath}${Platform.pathSeparator}$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<String> _saveAsPdf(
      String dirPath, String baseName, String content) async {
    final pdfDoc = pw.Document();
    final paragraphs = content.split('\n\n');
    pdfDoc.addPage(
      pw.MultiPage(
        build: (context) => paragraphs
            .map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(p, style: pw.TextStyle(fontSize: 12)),
                ))
            .toList(),
      ),
    );

    final bytes = await pdfDoc.save();
    final filename = '$baseName.pdf';
    final file = File('${dirPath}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String> _saveAsDocx(
      String dirPath, String baseName, String content) async {
    try {
      // If you have an asset template, ensure it's listed in pubspec.yaml under assets.
      final bytes =
          await rootBundle.load('assets/templates/summary_template.docx');
      final template = await DocxTemplate.fromBytes(bytes.buffer.asUint8List());
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final c = Content()
        ..add(TextContent('title', baseName))
        ..add(TextContent('date', formattedDate))
        ..add(TextContent('content', content.trim()));
      final generated = await template.generate(c);
      final filename = '$baseName.docx';
      final file = File('${dirPath}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(generated!, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('DOCX generation failed: $e — falling back to TXT');
      return _saveAsTxt(dirPath, baseName, content);
    }
  }
}
