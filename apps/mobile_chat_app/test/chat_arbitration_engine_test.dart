import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_arbitration.dart';
import 'package:mobile_chat_app/features/chat/chat_bot_registry.dart';

void main() {
  group('ChatArbitrationEngine', () {
    test('selects highest deterministic score from candidates', () {
      final engine = ChatArbitrationEngine(registry: ChatBotRegistry());

      final decision = engine.resolve(
        candidates: const [
          ArbitrationCandidate(botId: 'ask', baseWeight: 0.2),
          ArbitrationCandidate(botId: 'image_generation', baseWeight: 0.9),
        ],
        requestedBotId: 'ask',
      );

      expect(decision.tieDetected, isFalse);
      expect(decision.selected.bot.id, 'image_generation');
      expect(decision.selectedScore, greaterThan(0));
      expect(decision.candidateScores.length, 2);
    });

    test('falls back to default bot on tie', () {
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
            id: 'ab',
            displayName: 'AB',
            defaultSkillId: 'ab.default',
            skills: [
              ChatSkill(
                id: 'ab.default',
                inputMode: 'text',
                outputMode: 'text',
                isDefault: true,
              ),
            ],
          ),
          ChatBot(
            id: 'ba',
            displayName: 'BA',
            defaultSkillId: 'ba.default',
            skills: [
              ChatSkill(
                id: 'ba.default',
                inputMode: 'text',
                outputMode: 'text',
                isDefault: true,
              ),
            ],
          ),
        ],
      );
      final engine = ChatArbitrationEngine(registry: registry);

      final decision = engine.resolve(
        candidates: const [
          ArbitrationCandidate(botId: 'ab', baseWeight: 0.5),
          ArbitrationCandidate(botId: 'ba', baseWeight: 0.5),
        ],
        requestedBotId: 'ab',
      );

      expect(decision.tieDetected, isTrue);
      expect(decision.tieBotIds, containsAll(const ['ab', 'ba']));
      expect(decision.selected.bot.id, 'ask');
      expect(decision.fallbackToDefaultBot, isTrue);
    });

    test('falls back to requested/default when candidate list is empty', () {
      final engine = ChatArbitrationEngine(registry: ChatBotRegistry());

      final decision =
          engine.resolve(candidates: const [], requestedBotId: 'ask');

      expect(decision.tieDetected, isFalse);
      expect(decision.selected.bot.id, 'ask');
      expect(decision.candidateScores, isEmpty);
    });

    test('routes to sole candidate botId when exactly one candidate', () {
      final engine = ChatArbitrationEngine(registry: ChatBotRegistry());

      final decision = engine.resolve(
        candidates: const [
          ArbitrationCandidate(botId: 'image_generation', baseWeight: 0.8),
        ],
        requestedBotId: 'ask',
      );

      expect(decision.tieDetected, isFalse);
      expect(decision.selected.bot.id, 'image_generation');
      expect(decision.candidateScores.length, 1);
      expect(decision.candidateScores.first.botId, 'image_generation');
    });

    test('falls back to default bot when all candidates have zero probability',
        () {
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
            id: 'bot_a',
            displayName: 'Bot A',
            defaultSkillId: 'bot_a.default',
            skills: [
              ChatSkill(
                id: 'bot_a.default',
                inputMode: 'text',
                outputMode: 'text',
                isDefault: true,
              ),
            ],
          ),
          ChatBot(
            id: 'bot_b',
            displayName: 'Bot B',
            defaultSkillId: 'bot_b.default',
            skills: [
              ChatSkill(
                id: 'bot_b.default',
                inputMode: 'text',
                outputMode: 'text',
                isDefault: true,
              ),
            ],
          ),
        ],
      );
      final engine = ChatArbitrationEngine(registry: registry);

      final decision = engine.resolve(
        candidates: const [
          ArbitrationCandidate(botId: 'bot_a', baseWeight: 0.0),
          ArbitrationCandidate(botId: 'bot_b', baseWeight: 0.0),
        ],
        requestedBotId: 'bot_a',
      );

      expect(decision.tieDetected, isTrue);
      expect(decision.tieBotIds, containsAll(const ['bot_a', 'bot_b']));
      expect(decision.selected.bot.id, 'ask');
      expect(decision.fallbackToDefaultBot, isTrue);
    });
  });
}
