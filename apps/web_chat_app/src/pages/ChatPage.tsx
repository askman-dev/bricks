import { FormEvent, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { apiGet, apiPost } from '../lib/api';

type ChatMessage = { role: 'user' | 'assistant'; content: string };

type ChatSectionConfig = {
  id: string;
  category: string;
  provider: string;
  config?: {
    section_id?: string;
    section_name?: string;
    created_at?: string;
  };
  is_default: boolean;
  created_at: string;
  updated_at: string;
};

const SECTION_CATEGORY = 'chat_section';

function toSectionSlug(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || `sub-${Date.now()}`;
}

export function ChatPage() {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [composerMenuOpen, setComposerMenuOpen] = useState(false);
  const [sectionMenuOpen, setSectionMenuOpen] = useState(false);
  const [sections, setSections] = useState<ChatSectionConfig[]>([]);
  const [activeSectionId, setActiveSectionId] = useState('main');

  useEffect(() => {
    void loadSections();
  }, []);

  async function loadSections() {
    try {
      const data = await apiGet<ChatSectionConfig[]>(`/api/config?category=${SECTION_CATEGORY}`);
      const sorted = [...data].sort((a, b) => b.updated_at.localeCompare(a.updated_at));
      setSections(sorted);
      if (sorted.length > 0 && activeSectionId === 'main') {
        setActiveSectionId(sorted[0].id);
      }
    } catch {
      setSections([]);
    }
  }

  async function createSubsection() {
    const defaultName = `sub-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}`;
    const name = prompt('Subsection name', defaultName)?.trim();
    if (!name) return;

    try {
      const created = await apiPost<ChatSectionConfig>('/api/config', {
        category: SECTION_CATEGORY,
        provider: 'workspace',
        is_default: false,
        config: {
          section_id: toSectionSlug(name),
          section_name: name,
          created_at: new Date().toISOString(),
        },
      });
      setSections((prev) => [created, ...prev]);
      setActiveSectionId(created.id);
      setSectionMenuOpen(false);
    } catch {
      alert('Failed to create subsection. Please retry.');
    }
  }

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
        channelId: activeSectionId,
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

  const activeSectionName =
    sections.find((section) => section.id === activeSectionId)?.config?.section_name ?? '主区';

  return (
    <section className="chat-mobile-page">
      <header className="mobile-topbar">
        <button
          type="button"
          className="icon-btn"
          aria-label="Open navigation menu"
          onClick={() => {
            setDrawerOpen((prev) => !prev);
            setComposerMenuOpen(false);
            setSectionMenuOpen(false);
          }}
        >
          ☰
        </button>
        <h1>Bricks</h1>
        <button
          type="button"
          className="section-btn"
          onClick={() => {
            setSectionMenuOpen((prev) => !prev);
            setComposerMenuOpen(false);
            setDrawerOpen(false);
          }}
        >
          {activeSectionName} ▾
        </button>
      </header>

      <div className="chat-meta">🧰 ask</div>
      <article className="chat-message-card" aria-label="message-list">
        {messages.length === 0 ? (
          <p className="chat-empty">No messages yet.</p>
        ) : (
          messages.map((message, index) => (
            <div
              key={`${message.role}-${index}`}
              className={`chat-bubble chat-bubble--${message.role}`}
            >
              {message.content}
            </div>
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
            aria-label="Composer options"
            onClick={() => {
              setComposerMenuOpen((prev) => !prev);
              setDrawerOpen(false);
              setSectionMenuOpen(false);
            }}
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

      {drawerOpen && (
        <>
          <button
            className="drawer-overlay"
            type="button"
            aria-label="Close navigation menu"
            onClick={() => setDrawerOpen(false)}
          />
          <aside className="sidebar-drawer" aria-label="Navigation drawer">
            <button
              type="button"
              className="icon-btn drawer-close"
              aria-label="Close drawer"
              onClick={() => setDrawerOpen(false)}
            >
              ✕
            </button>
            <button
              type="button"
              className="drawer-item"
              onClick={() => {
                setMessages([]);
                setDrawerOpen(false);
              }}
            >
              New context
            </button>
            <button
              type="button"
              className="drawer-item"
              onClick={() => {
                navigate('/settings/model');
                setDrawerOpen(false);
              }}
            >
              Model
            </button>
            <Link to="/settings" className="drawer-item" onClick={() => setDrawerOpen(false)}>
              Settings
            </Link>
          </aside>
        </>
      )}

      {composerMenuOpen && (
        <div className="floating-menu floating-menu--composer" role="menu" aria-label="Composer menu">
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              setMessages([]);
              setComposerMenuOpen(false);
            }}
          >
            Clear messages
          </button>
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              navigate('/settings/model');
              setComposerMenuOpen(false);
            }}
          >
            Model
          </button>
        </div>
      )}

      {sectionMenuOpen && (
        <div className="floating-menu floating-menu--right" role="menu" aria-label="Section menu">
          <button type="button" role="menuitem" onClick={() => void createSubsection()}>
            新建子区
          </button>
          {sections.length === 0 ? (
            <button type="button" role="menuitem" className="muted-item" disabled>
              暂无子区
            </button>
          ) : (
            sections.map((section) => {
              const selected = section.id === activeSectionId;
              return (
                <button
                  key={section.id}
                  type="button"
                  role="menuitemradio"
                  aria-checked={selected}
                  className={selected ? 'menu-item-selected' : undefined}
                  onClick={() => {
                    setActiveSectionId(section.id);
                    setSectionMenuOpen(false);
                  }}
                >
                  {section.config?.section_name ?? section.config?.section_id ?? section.id}
                </button>
              );
            })
          )}
        </div>
      )}
    </section>
  );
}
