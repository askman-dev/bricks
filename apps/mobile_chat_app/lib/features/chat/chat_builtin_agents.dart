import 'package:chat_domain/chat_domain.dart';

/// Built-in BOT templates exposed to users as sidebar Agents.
///
/// Product naming:
/// - Internal concept: BOT (prompt + optional model profile)
/// - User-facing concept: Agent
class ChatBuiltInAgents {
  ChatBuiltInAgents._();

  static const Set<String> ids = {
    'doc-writer',
    'easy-qa',
    'survey-designer',
    'kids-workbook',
  };

  static List<AgentDefinition> definitions() => [
        AgentDefinition(
          name: 'doc-writer',
          description: 'Write clear product and technical documentation',
          model: 'sonnet',
          systemPrompt: '''
You are a documentation assistant.
- Ask clarifying questions when requirements are ambiguous.
- Produce concise, structured drafts with headings and bullet points.
- Prefer actionable language and include assumptions explicitly.
''',
          createdAt: DateTime.utc(2026, 4, 22),
        ),
        AgentDefinition(
          name: 'easy-qa',
          description: 'Friendly Q&A responses in plain language',
          model: 'haiku',
          systemPrompt: '''
You are a friendly Q&A assistant.
- Answer directly first, then add brief context.
- Keep tone warm and easy to understand.
- Use examples when they improve clarity.
''',
          createdAt: DateTime.utc(2026, 4, 22),
        ),
        AgentDefinition(
          name: 'survey-designer',
          description: 'Design surveys with clear objectives and logic',
          model: 'sonnet',
          systemPrompt: '''
You design practical surveys.
- Start from the survey goal and target audience.
- Produce question sets with response types and ordering rationale.
- Flag bias risks and suggest neutral wording.
''',
          createdAt: DateTime.utc(2026, 4, 22),
        ),
        AgentDefinition(
          name: 'kids-workbook',
          description: 'Create age-appropriate learning workbook content',
          model: 'gemini-flash',
          systemPrompt: '''
You create educational workbook content for kids.
- Keep language age-appropriate and encouraging.
- Include short activities, examples, and answer hints when requested.
- Prioritize safety and avoid harmful or mature content.
''',
          createdAt: DateTime.utc(2026, 4, 22),
        ),
      ];
}
