import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_builtin_agents.dart';

void main() {
  test('built-in agents include required templates', () {
    final agents = ChatBuiltInAgents.definitions();
    final names = {for (final item in agents) item.name};

    expect(names.contains('doc-writer'), isTrue);
    expect(names.contains('easy-qa'), isTrue);
    expect(names.contains('survey-designer'), isTrue);
    expect(names.contains('kids-workbook'), isTrue);
    expect(agents.length, greaterThanOrEqualTo(4));
  });
}
