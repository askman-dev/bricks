import 'chat_bot_registry.dart';

class BotCandidateScore {
  const BotCandidateScore({
    required this.botId,
    required this.score,
    required this.confidence,
    required this.reason,
  });

  final String botId;
  final double score;
  final double confidence;
  final String reason;
}

class ArbitrationCandidate {
  const ArbitrationCandidate({
    required this.botId,
    required this.baseWeight,
  });

  final String botId;
  final double baseWeight;
}

class ArbitrationDecision {
  const ArbitrationDecision({
    required this.selected,
    required this.candidateScores,
    required this.tieDetected,
    required this.tieBotIds,
    required this.selectedScore,
    required this.fallbackToDefaultBot,
    required this.reason,
  });

  final ResolvedChatDispatch selected;
  final List<BotCandidateScore> candidateScores;
  final bool tieDetected;
  final List<String> tieBotIds;
  final double selectedScore;
  final bool fallbackToDefaultBot;
  final String reason;
}

class ChatArbitrationEngine {
  const ChatArbitrationEngine({required this.registry});

  final ChatBotRegistry registry;

  ArbitrationDecision resolve({
    required List<ArbitrationCandidate> candidates,
    required String? requestedBotId,
  }) {
    if (candidates.length <= 1) {
      final selected = registry.resolve(requestedBotId: requestedBotId);
      return ArbitrationDecision(
        selected: selected,
        candidateScores: selected.fallbackToDefaultBot
            ? [
                BotCandidateScore(
                  botId: selected.bot.id,
                  score: 1,
                  confidence: 1,
                  reason: selected.reason,
                ),
              ]
            : const [],
        tieDetected: false,
        tieBotIds: const [],
        selectedScore: 1,
        fallbackToDefaultBot: selected.fallbackToDefaultBot,
        reason: selected.reason,
      );
    }

    final scores = candidates
        .map(
          (candidate) => BotCandidateScore(
            botId: candidate.botId,
            score: _clamp01(candidate.baseWeight),
            confidence: _confidenceForWeight(candidate.baseWeight),
            reason: 'Weighted from participant probability.',
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final topScore = scores.first.score;
    final ties = scores
        .where((item) => item.score == topScore)
        .map((item) => item.botId)
        .toList();

    if (ties.length > 1) {
      final fallback = registry.resolve(requestedBotId: null);
      return ArbitrationDecision(
        selected: fallback,
        candidateScores: scores,
        tieDetected: true,
        tieBotIds: ties,
        selectedScore: topScore,
        fallbackToDefaultBot: true,
        reason: 'Tie detected (${ties.join(', ')}), routed to default bot.',
      );
    }

    final selected = registry.resolve(requestedBotId: scores.first.botId);
    return ArbitrationDecision(
      selected: selected,
      candidateScores: scores,
      tieDetected: false,
      tieBotIds: const [],
      selectedScore: scores.first.score,
      fallbackToDefaultBot: selected.fallbackToDefaultBot,
      reason: 'Selected highest score candidate ${scores.first.botId}.',
    );
  }

  double _clamp01(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

  double _confidenceForWeight(double weight) => 0.5 + (_clamp01(weight) * 0.5);
}
