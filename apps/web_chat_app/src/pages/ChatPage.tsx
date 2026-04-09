import { FormEvent, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { apiPost } from '../lib/api';

type ChatMessage = { role: 'user' | 'assistant'; content: string };

type MenuState = 'none' | 'main' | 'section';

export function ChatPage() {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [menuState, setMenuState] = useState<MenuState>('none');

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
    <section className="chat-mobile-page">
      <header className="mobile-topbar">
        <button
          type="button"
          className="icon-btn"
          aria-label="Open navigation menu"
          onClick={() => setMenuState((prev) => (prev === 'main' ? 'none' : 'main'))}
        >
          ☰
        </button>
        <h1>Bricks</h1>
        <button
          type="button"
          className="section-btn"
          onClick={() => setMenuState((prev) => (prev === 'section' ? 'none' : 'section'))}
        >
          主区 ▾
        </button>
      </header>

      <div className="chat-meta">🧰 ask</div>
      <article className="chat-message-card" aria-label="message-list">
        {messages.length === 0 ? (
          <p>No messages yet.</p>
        ) : (
          messages.map((m, index) => (
            <p key={`${m.role}-${index}`}>
              <strong>{m.role === 'user' ? 'You' : 'Assistant'}：</strong>
              {m.content}
            </p>
          ))
        )}
      </article>

      <form className="composer-mobile" onSubmit={onSubmit}>
        <input
          value={input}
          onChange={(event) => setInput(event.target.value)}
          placeholder="Ask Bricks to create something..."
        />
        <div className="composer-bottom-row">
          <button
            type="button"
            className="icon-btn"
            aria-label="Context menu"
            onClick={() => setMenuState((prev) => (prev === 'main' ? 'none' : 'main'))}
          >
            ☷
          </button>
          <button
            type="submit"
            className="send-btn"
            disabled={loading || !input.trim()}
            aria-label="Send message"
          >
            <span aria-hidden="true">{loading ? '…' : '➤'}</span>
          </button>
        </div>
      </form>

      {menuState === 'main' && (
        <div className="floating-menu floating-menu--left" role="menu" aria-label="Main menu">
          <button
            type="button"
            role="menuitem"
            onClick={() => { setMessages([]); setMenuState('none'); }}
          >
            New context
          </button>
          <button
            type="button"
            role="menuitem"
            onClick={() => { navigate('/settings/model'); setMenuState('none'); }}
          >
            Model
          </button>
          <button type="button" role="menuitem" disabled>
            Agents (coming soon)
          </button>
          <Link to="/settings" role="menuitem" onClick={() => setMenuState('none')}>
            Settings
          </Link>
        </div>
      )}

      {menuState === 'section' && (
        <div className="floating-menu floating-menu--right" role="menu" aria-label="Section menu">
          <button type="button" role="menuitem" onClick={() => setMenuState('none')}>Back to main</button>
          <button type="button" role="menuitem" disabled>New subsection (coming soon)</button>
          <button type="button" role="menuitem" className="muted-item">
            sub-2026-04-09-21-31-16-844
          </button>
        </div>
      )}
    </section>
  );
}
