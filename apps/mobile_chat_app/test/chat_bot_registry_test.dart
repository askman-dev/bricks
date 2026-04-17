import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_bot_registry.dart';

void main() {
  group('ChatBotRegistry', () {
    test('resolves registered bot and its default skill', () {
      final registry = ChatBotRegistry();

      final resolved = registry.resolve(requestedBotId: 'image_generation');

      expect(resolved.bot.id, 'image_generation');
      expect(resolved.skillId, 'image_generation.default');
      expect(resolved.fallbackToDefaultBot, isFalse);
    });

    test('falls back to default bot when requested bot is missing', () {
      final registry = ChatBotRegistry();

      final resolved = registry.resolve(requestedBotId: 'non-existent-bot');

      expect(resolved.bot.id, 'ask');
      expect(resolved.skillId, 'ask.default');
      expect(resolved.fallbackToDefaultBot, isTrue);
    });

    test('falls back when requested bot default skill is unavailable', () {
      final registry = ChatBotRegistry(
        bots: const [
          ChatBot(
            id: 'ask',
            displayName: 'Ask',
            defaultSkillId: 'ask.default',
            skills: [
              ChatSkill(
                id: 'ask.default',
                inputMode: 'text',
                outputMode: 'text',
                isDefault: true,
              ),
            ],
          ),
          ChatBot(
            id: 'broken_bot',
            displayName: 'Broken',
            defaultSkillId: 'broken.default',
            skills: [
              ChatSkill(
                id: 'broken.other',
                inputMode: 'text',
                outputMode: 'text',
              ),
            ],
          ),
        ],
      );

      final resolved = registry.resolve(requestedBotId: 'broken_bot');

      expect(resolved.bot.id, 'ask');
      expect(resolved.skillId, 'ask.default');
      expect(resolved.fallbackToDefaultBot, isTrue);
    });
  });
}
