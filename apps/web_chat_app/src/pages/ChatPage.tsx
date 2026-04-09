import { FormEvent, useState } from 'react';
import { apiPost } from '../lib/api';

type ChatMessage = { role: 'user' | 'assistant'; content: string };

export function ChatPage() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    const trimmed = input.trim();
    if (!trimmed || loading) return;
    const sessionId = 'react-session-default';
    const taskId = `task-${Date.now()}`;
    const userMessageId = `msg-user-${Date.now()}`;
    const assistantMessageId = `msg-assistant-${Date.now()}`;

    setLoading(true);
    setMessages((prev) => [...prev, { role: 'user', content: trimmed }]);
    setInput('');

    try {
      const response = await apiPost<{ text: string }>('/api/chat/respond', {
        taskId,
        idempotencyKey: taskId,
        channelId: 'chat',
        sessionId,
        userMessageId,
        assistantMessageId,
        userMessage: trimmed,
      });
      setMessages((prev) => [...prev, { role: 'assistant', content: response.text }]);
    } catch {
      setMessages((prev) => [
        ...prev,
        { role: 'assistant', content: 'Request failed. Please verify login and API config.' },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="chat-page">
      <h2>Conversation</h2>
      <div className="message-list" aria-label="message-list">
        {messages.map((m, index) => (
          <div key={`${m.role}-${index}`} className={`bubble ${m.role}`}>
            <strong>{m.role === 'user' ? 'You' : 'Assistant'}:</strong> {m.content}
          </div>
        ))}
      </div>
      <form className="composer" onSubmit={onSubmit}>
        <input
          value={input}
          onChange={(event) => setInput(event.target.value)}
          placeholder="Type your message"
        />
        <button type="submit" disabled={loading || !input.trim()}>
          {loading ? 'Sending...' : 'Send'}
        </button>
      </form>
    </section>
  );
}
