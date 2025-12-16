// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _version = 'Unknown';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL')),
        );
      }
      return;
    }

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email,
      {String subject = '', String body = ''}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LitePad', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Version $_version', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            const Text(
              'A lightweight modern notepad with offline summarization and voice features. '
              'Quick summaries, local storage, and simple sharing — designed for privacy and speed.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 18),
            const Text('Developer',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('God\'swill Okechukwu .M.'),
              subtitle: const Text('Computer Software Engineer'),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openUrl(
                    'https://www.facebook.com/jemrymedia.juniorfabiankane'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _sendEmail('junkaytech@gmail.com',
                      subject: 'LitePad inquiry'),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Contact'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () =>
                      _openUrl('https://wa.me/message/3S6EGUKQE5SSA1'),
                  icon: const Icon(Icons.code),
                  label: const Text('Connect'),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => _openUrl(
                    'https://privacy.microsoft.com/en-us/privacystatement'),
                child: const Text('Privacy Policy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
