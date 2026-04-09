import { FormEvent, useState } from 'react';
import { Link } from 'react-router-dom';
import { apiPost } from '../lib/api';

type ChatMessage = { role: 'user' | 'assistant'; content: string };

type MenuState = 'none' | 'main' | 'section';

export function ChatPage() {
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
          <p>
            太棒了！看来你对《卡卡颂》（Carcassonne）很感兴趣。这里是移动端布局基准内容，
            方便和截图逐项比对间距、字号、圆角与色彩。
          </p>
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
          <button type="button" className="icon-btn" aria-label="Context menu">
            ☷
          </button>
          <button type="submit" className="send-btn" disabled={loading || !input.trim()}>
            {loading ? '…' : '➤'}
          </button>
        </div>
      </form>

      {menuState === 'main' && (
        <div className="floating-menu floating-menu--left" role="menu" aria-label="Main menu">
          <button type="button">新上下文</button>
          <button type="button">模型</button>
          <button type="button">Agents</button>
          <Link to="/settings" onClick={() => setMenuState('none')}>
            信息
          </Link>
        </div>
      )}

      {menuState === 'section' && (
        <div className="floating-menu floating-menu--right" role="menu" aria-label="Section menu">
          <button type="button">回到主区</button>
          <button type="button">新建子区</button>
          <button type="button" className="muted-item">
            sub-2026-04-09-21-31-16-844
          </button>
        </div>
      )}
    </section>
  );
}
