import 'package:platform_bridge/platform_bridge.dart';
import 'package:workspace_fs/workspace_fs.dart';

/// Creates an [AgentsRepository] configured for the current platform.
Future<AgentsRepository> createAgentsRepository() async {
  final paths = PlatformPathsImpl();
  final agentsDir = await paths.agentsDirectory();
  return AgentsRepository(agentsPath: agentsDir);
}
