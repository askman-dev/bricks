import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/session/session_settings_page.dart';

void main() {
  group('SessionSettingsPage', () {
    testWidgets('shows empty state when no agents', (tester) async {
      final coordinator = ParticipantManager();

      await tester.pumpWidget(
        MaterialApp(home: SessionSettingsPage(coordinator: coordinator)),
      );

      expect(find.text('Session Settings'), findsOneWidget);
      // Empty-state message is present (partial match via contains).
      expect(find.textContaining('No agents in this session'), findsOneWidget);
    });

    testWidgets('shows agent tile with name and slider', (tester) async {
      final coordinator = ParticipantManager()
        ..addParticipant(const AgentParticipant(
          agentId: 'analyst',
          agentName: 'Analyst',
          isEnabled: true,
          probability: 0.3,
        ));

      await tester.pumpWidget(
        MaterialApp(home: SessionSettingsPage(coordinator: coordinator)),
      );

      expect(find.text('Analyst'), findsOneWidget);
      // Slider and checkbox are present.
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      // Probability label shows 30%.
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('toggling checkbox calls setEnabled', (tester) async {
      final coordinator = ParticipantManager()
        ..addParticipant(const AgentParticipant(
          agentId: 'critic',
          agentName: 'Critic',
          isEnabled: true,
          probability: 0.5,
        ));

      await tester.pumpWidget(
        MaterialApp(home: SessionSettingsPage(coordinator: coordinator)),
      );

      // Uncheck the checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(
        coordinator.participants.findById('critic')!.isEnabled,
        isFalse,
      );
    });

    testWidgets('shows multiple agents', (tester) async {
      final coordinator = ParticipantManager()
        ..addParticipant(const AgentParticipant(
          agentId: 'analyst',
          agentName: 'Analyst',
        ))
        ..addParticipant(const AgentParticipant(
          agentId: 'critic',
          agentName: 'Critic',
        ));

      await tester.pumpWidget(
        MaterialApp(home: SessionSettingsPage(coordinator: coordinator)),
      );

      expect(find.text('Analyst'), findsOneWidget);
      expect(find.text('Critic'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
    });
  });
}
