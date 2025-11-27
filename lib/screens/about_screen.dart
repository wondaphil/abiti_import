import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = '';
  String buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'wondaphil@gmail.com',
      query: Uri.encodeFull('subject=Abiti Import App Feedback'),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Abiti Import')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/logo_splash.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Inventory App',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Version $version (Build $buildNumber)',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const Divider(height: 40),
            const Text(
              'Developed by',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _launchEmail,
              child: const Text(
                'wondaphil@gmail.com',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.teal,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Abiti Import Inventory App helps manage items and categories, monitor stock transactions, '
              'and maintain detailed records.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© ${DateTime.now().year} Wondwossen Philemon',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}