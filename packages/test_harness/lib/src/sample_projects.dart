import 'dart:io';
import 'package:project_system/project_system.dart';

/// Provides pre-built sample [Project] instances for tests.
class SampleProjects {
  const SampleProjects._();

  static const _manifest = ProjectManifest(
    name: 'hello-world',
    type: ProjectType.website,
    description: 'A minimal hello-world website project.',
    entryPoint: 'index.html',
  );

  /// A minimal hello-world website project (no filesystem side-effects).
  ///
  /// [basePath] defaults to [Directory.systemTemp] when not supplied.
  static Project helloWorld({String? basePath}) {
    final resolvedBase = basePath ?? Directory.systemTemp.path;
    return Project(
      name: 'hello-world',
      path: '$resolvedBase${Platform.pathSeparator}hello-world',
      type: ProjectType.website,
      manifest: _manifest,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );
  }
}
