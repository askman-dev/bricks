/// Website/app project abstraction layer for Bricks.
///
/// Defines what a project is: schema, file layout, creation,
/// preview/run support, AI bridge, and lifecycle snapshots.
library project_system;

export 'src/project_model/project.dart';
export 'src/project_model/project_manifest.dart';
export 'src/project_model/project_snapshot.dart';
export 'src/project_model/project_type.dart';
export 'src/website_project/website_ai_bridge.dart';
export 'src/website_project/website_file_layout.dart';
export 'src/website_project/website_preview_service.dart';
export 'src/website_project/website_project_factory.dart';
