import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { apiGet, setAuthToken } from './lib/api';
import { ChatPage } from './pages/ChatPage';
import { SettingsPage } from './pages/SettingsPage';
import { ModelSettingsPage } from './pages/ModelSettingsPage';

type UserProfile = { id: string; email: string | null; created_at: string; updated_at: string }; // snake_case matches backend API
type AuthMeResponse = { user: UserProfile; oauth_connections: unknown[] };

function LoginPage() {
  const returnTo = encodeURIComponent(window.location.origin + '/chat');
  return (
    <main className="center-page">
      <h1>Bricks</h1>
      <p>React frontend rewrite</p>
      <a className="primary-btn" href={`/api/auth/github?return_to=${returnTo}`}>
        Login with GitHub
      </a>
    </main>
  );
}

function PlaceholderPage({ title }: { title: string }) {
  return (
    <section className="page-panel">
      <h2>{title}</h2>
      <p>{title} is available from the React sidebar navigation.</p>
    </section>
  );
}

export function App() {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    // Extract auth_token from URL fragment for cross-origin OAuth flows
    const hash = window.location.hash.slice(1);
    const params = new URLSearchParams(hash);
    const fragmentToken = params.get('auth_token');
    if (fragmentToken) {
      setAuthToken(fragmentToken);
      params.delete('auth_token');
      const newHash = params.toString();
      window.history.replaceState(
        null,
        '',
        newHash ? `#${newHash}` : window.location.pathname + window.location.search,
      );
    }

    apiGet<AuthMeResponse>('/api/auth/me')
      .then((data) => setUser(data.user))
      .catch(() => setUser(null))
      .finally(() => setChecked(true));
  }, []);

  if (!checked) return <main className="center-page">Loading...</main>;
  if (!user) return <LoginPage />;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <h3>Bricks</h3>
        <nav>
          <NavLink to="/chat">Chat</NavLink>
          <NavLink to="/workspace">Workspace</NavLink>
          <NavLink to="/resources">Resources</NavLink>
          <NavLink to="/settings">Settings</NavLink>
        </nav>
      </aside>
      <main className="content">
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
          <Route path="/workspace" element={<PlaceholderPage title="Workspace" />} />
          <Route path="/resources" element={<PlaceholderPage title="Resources" />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/settings/model" element={<ModelSettingsPage />} />
          <Route path="*" element={<Navigate to="/chat" replace />} />
        </Routes>
      </main>
    </div>
  );
}
