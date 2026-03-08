import 'dart:io';
import '../project_model/project.dart';
import '../project_model/project_manifest.dart';
import '../project_model/project_type.dart';
import 'website_file_layout.dart';

/// Creates new website projects on the filesystem.
class WebsiteProjectFactory {
  const WebsiteProjectFactory();

  /// Creates a new website project at [projectsBasePath]/[name].
  ///
  /// Writes the `bricks.project.yaml` manifest and a minimal HTML/CSS/JS
  /// skeleton defined by [WebsiteFileLayout].
  Future<Project> create({
    required String name,
    required String projectsBasePath,
    String? description,
    ProjectType type = ProjectType.website,
  }) async {
    final projectPath = '$projectsBasePath${Platform.pathSeparator}$name';
    await Directory(projectPath).create(recursive: true);

    final manifest = ProjectManifest(
      name: name,
      type: type,
      description: description,
    );

    // Write manifest
    final manifestFile = File(
      '$projectPath${Platform.pathSeparator}bricks.project.yaml',
    );
    await manifestFile.writeAsString(_manifestToYaml(manifest));

    // Write skeleton files
    final layout = WebsiteFileLayout(projectPath: projectPath);
    await layout.writeSkeleton();

    return Project(
      name: name,
      path: projectPath,
      type: type,
      manifest: manifest,
      createdAt: DateTime.now(),
    );
  }

  String _manifestToYaml(ProjectManifest m) => '''
name: ${m.name}
type: ${m.type.name}
description: ${m.description ?? ''}
entry_point: ${m.entryPoint}
version: ${m.version}
''';
}
