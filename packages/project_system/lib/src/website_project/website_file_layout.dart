import 'dart:io';

/// Defines and writes the canonical file layout for a website project.
class WebsiteFileLayout {
  const WebsiteFileLayout({required String projectPath})
      : _projectPath = projectPath;

  final String _projectPath;

  /// Writes a minimal HTML/CSS/JS skeleton to the project directory.
  Future<void> writeSkeleton() async {
    final sep = Platform.pathSeparator;

    await File('$_projectPath${sep}index.html').writeAsString(_indexHtml);
    await File('$_projectPath${sep}style.css').writeAsString(_styleCss);
    await File('$_projectPath${sep}script.js').writeAsString(_scriptJs);
  }

  static const _indexHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>My Bricks Site</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <h1>Hello, Bricks!</h1>
  <script src="script.js"></script>
</body>
</html>
''';

  static const _styleCss = '''/* styles */
body {
  font-family: sans-serif;
  margin: 2rem;
}
''';

  static const _scriptJs = '''// scripts
console.log('Bricks project loaded');
''';
}
