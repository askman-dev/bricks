/// Stable interface contracts for the Bricks agent system.
///
/// Consumers (such as the chat app) should depend on this package
/// rather than coupling directly to `agent_core` internals.
library agent_sdk_contract;

export 'src/agent_client.dart';
export 'src/agent_session.dart';
export 'src/event_stream.dart';
export 'src/participant_contracts.dart';
export 'src/settings_contracts.dart';
export 'src/skill_contracts.dart';
export 'src/sub_agent_contracts.dart';
export 'src/tool_contracts.dart';
