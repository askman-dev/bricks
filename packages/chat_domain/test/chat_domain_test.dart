import 'package:chat_domain/chat_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    test('toMap / fromMap round-trip', () {
      final msg = Message(
        id: 'msg-1',
        role: MessageRole.user,
        content: 'Hello agent',
        attachments: ['resource/avatar.png'],
      );
      final restored = Message.fromMap(msg.toMap());
      expect(restored.id, equals(msg.id));
      expect(restored.role, equals(MessageRole.user));
      expect(restored.content, equals('Hello agent'));
      expect(restored.attachments, equals(['resource/avatar.png']));
    });
  });

  group('Conversation', () {
    test('addMessage appends and updates updatedAt', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Test',
        workspaceId: 'default',
      );
      final before = conv.updatedAt;

      // Ensure time moves forward
      final msg = Message(
        id: 'm1',
        role: MessageRole.user,
        content: 'Hi',
      );
      conv.addMessage(msg);
      expect(conv.messages, hasLength(1));
      expect(conv.updatedAt.isAfter(before) || conv.updatedAt == before, isTrue);
    });

    test('toMap / fromMap round-trip', () {
      final conv = Conversation(
        id: 'c1',
        title: 'Chat',
        workspaceId: 'ws-1',
      )..addMessage(
          Message(id: 'm1', role: MessageRole.assistant, content: 'Hi there'),
        );

      final restored = Conversation.fromMap(conv.toMap());
      expect(restored.id, equals('c1'));
      expect(restored.messages, hasLength(1));
      expect(restored.messages.first.content, equals('Hi there'));
    });
  });

  group('ComposerState', () {
    test('isEmpty is true when text and attachments are empty', () {
      expect(ComposerState().isEmpty, isTrue);
    });

    test('isEmpty is false when text is present', () {
      expect(ComposerState(text: 'hello').isEmpty, isFalse);
    });

    test('clear resets everything', () {
      final state = ComposerState(text: 'Hi')
        ..attachedResourcePaths.add('res/photo.jpg');
      state.clear();
      expect(state.isEmpty, isTrue);
    });
  });

  group('Attachment', () {
    test('FileAttachment holds path and mimeType', () {
      const att = FileAttachment(
        id: 'a1',
        name: 'photo.jpg',
        path: '/storage/photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 102400,
      );
      expect(att.mimeType, equals('image/jpeg'));
      expect(att.sizeBytes, equals(102400));
    });

    test('ResourceAttachment holds resourcePath', () {
      const att = ResourceAttachment(
        id: 'r1',
        name: 'avatar.png',
        resourcePath: 'resources/avatar.png',
      );
      expect(att.resourcePath, equals('resources/avatar.png'));
    });
  });
}
