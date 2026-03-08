import 'package:flutter/material.dart';

/// Screen that hosts the WebView preview of a website project.
class WebsitePreviewScreen extends StatelessWidget {
  const WebsitePreviewScreen({super.key, required this.previewUrl});

  final Uri previewUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(previewUrl.host)),
      body: Center(
        child: Text('WebView preview of $previewUrl – coming soon'),
      ),
    );
  }
}
