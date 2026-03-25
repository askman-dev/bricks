import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/session/model_selection_dialog.dart';
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

  group('ModelSelectionDialog', () {
    testWidgets('shows all Gemini model options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelSelectionDialog(currentModel: kGeminiModels.first),
          ),
        ),
      );

      for (final modelId in kGeminiModels) {
        expect(find.text(modelId), findsOneWidget);
      }
    });

    testWidgets('pre-selects the current model', (tester) async {
      const current = 'gemini-3.1-flash-lite-preview';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelSelectionDialog(currentModel: current),
          ),
        ),
      );

      // The radio for the current model should be selected.
      final radios = tester.widgetList<Radio<String>>(find.byType(Radio<String>));
      final selected = radios.where((r) => r.groupValue == r.value);
      expect(selected.map((r) => r.value).single, equals(current));
    });

    testWidgets('tapping a radio changes selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelSelectionDialog(currentModel: kGeminiModels.first),
          ),
        ),
      );

      // Tap the second model option.
      await tester.tap(find.text(kGeminiModels[1]));
      await tester.pump();

      final radios = tester.widgetList<Radio<String>>(find.byType(Radio<String>));
      final selected = radios.where((r) => r.groupValue == r.value);
      expect(selected.map((r) => r.value).single, equals(kGeminiModels[1]));
    });

    testWidgets('Cancel button dismisses dialog without returning value',
        (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => ModelSelectionDialog(
                    currentModel: kGeminiModels.first,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Select button dismisses dialog returning selected model',
        (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => ModelSelectionDialog(
                    currentModel: kGeminiModels.first,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select a different model.
      await tester.tap(find.text(kGeminiModels[2]));
      await tester.pump();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(result, equals(kGeminiModels[2]));
    });
  });
}
