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
  const [agentsExpanded, setAgentsExpanded] = useState(true);
  const [channelsExpanded, setChannelsExpanded] = useState(true);
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

  const activeSection = sections.find((section) => section.id === activeSectionId);
  const activeSectionName =
    activeSectionId === 'main'
      ? '主区'
      : activeSection?.config?.section_name ?? activeSection?.config?.section_id ?? activeSection?.id ?? '主区';

  function createDrawerChannel() {
    void createSubsection().finally(() => setDrawerOpen(false));
  }

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
            <header className="drawer-header">
              <button
                type="button"
                className="icon-btn drawer-back"
                aria-label="Close navigation menu"
                onClick={() => setDrawerOpen(false)}
              >
                ←
              </button>
              <h2>Navigation</h2>
              <Link
                to="/settings"
                className="icon-btn drawer-settings-link"
                aria-label="Open settings"
                onClick={() => setDrawerOpen(false)}
              >
                ⚙
              </Link>
            </header>

            <button
              type="button"
              className="drawer-current-chat"
              onClick={() => {
                setMessages([]);
                setDrawerOpen(false);
              }}
            >
              <span className="drawer-current-icon" aria-hidden="true">
                💬
              </span>
              <span>
                <strong>Current Chat</strong>
                <small>You are here</small>
              </span>
            </button>

            <section className="drawer-group">
              <div className="drawer-group-header">
                <button
                  type="button"
                  className="drawer-group-toggle"
                  aria-label="Agents section"
                  aria-expanded={agentsExpanded}
                  onClick={() => setAgentsExpanded((prev) => !prev)}
                >
                  <span>{agentsExpanded ? '⌄' : '›'} Agents</span>
                </button>
                <button
                  type="button"
                  className="drawer-group-action"
                  onClick={() => {
                    alert('未开发的功能');
                  }}
                >
                  ⚙ 配置
                </button>
              </div>
              {agentsExpanded && (
                <p className="drawer-empty-hint" role="status">
                  在设置中新建 Agents
                </p>
              )}
            </section>

            <section className="drawer-group">
              <div className="drawer-group-header">
                <button
                  type="button"
                  className="drawer-group-toggle"
                  aria-label="Channels section"
                  aria-expanded={channelsExpanded}
                  onClick={() => setChannelsExpanded((prev) => !prev)}
                >
                  <span>{channelsExpanded ? '⌄' : '›'} 频道</span>
                </button>
                <button
                  type="button"
                  className="drawer-group-action"
                  onClick={() => {
                    createDrawerChannel();
                  }}
                >
                  ⊕ 新建频道
                </button>
              </div>
              {channelsExpanded && (
                <div className="drawer-channel-list">
                  {sections.length === 0 ? (
                    <button
                      type="button"
                      className={`drawer-channel-item ${activeSectionId === 'main' ? 'selected' : ''}`}
                      onClick={() => {
                        setActiveSectionId('main');
                        setDrawerOpen(false);
                      }}
                    >
                      <span className="drawer-channel-icon">⌂</span>
                      <span>
                        <strong>默认频道</strong>
                        <small>Default channel</small>
                      </span>
                    </button>
                  ) : (
                    sections.map((section) => {
                      const selected = section.id === activeSectionId;
                      return (
                        <button
                          key={section.id}
                          type="button"
                          className={`drawer-channel-item ${selected ? 'selected' : ''}`}
                          onClick={() => {
                            setActiveSectionId(section.id);
                            setDrawerOpen(false);
                          }}
                        >
                          <span className="drawer-channel-icon">⌂</span>
                          <span>
                            <strong>
                              {section.config?.section_name ?? section.config?.section_id ?? section.id}
                            </strong>
                            <small>子区</small>
                          </span>
                        </button>
                      );
                    })
                  )}
                </div>
              )}
            </section>
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
          <div className="menu-group" role="none">
            <button
              type="button"
              role="menuitemradio"
              aria-checked={activeSectionId === 'main'}
              className={activeSectionId === 'main' ? 'menu-item-selected' : undefined}
              onClick={() => {
                setActiveSectionId('main');
                setSectionMenuOpen(false);
              }}
            >
              主区
            </button>
            <button type="button" role="menuitem" onClick={() => void createSubsection()}>
              新建子区
            </button>
          </div>
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
