/// Filesystem mapping layer for Bricks.
///
/// Maps the local device filesystem to app-level concepts:
/// workspaces, projects, resources, conversations, and app config.
library workspace_fs;

export 'src/agents_repository.dart';
export 'src/workspace_locator.dart';
export 'src/workspace_repository.dart';
export 'src/resources_repository.dart';
export 'src/projects_repository.dart';
export 'src/conversations_repository.dart';
export 'src/app_config_repository.dart';
export 'src/watchers.dart';
export 'src/path_validator.dart';
