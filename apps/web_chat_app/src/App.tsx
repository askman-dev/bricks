import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { apiGet } from './lib/api';
import { ChatPage } from './pages/ChatPage';

type UserProfile = { id: string; email: string };

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
    apiGet<UserProfile>('/api/auth/me')
      .then(setUser)
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
          <NavLink to="/projects">Projects</NavLink>
          <NavLink to="/skills">Skills</NavLink>
          <NavLink to="/resources">Resources</NavLink>
        </nav>
      </aside>
      <main className="content">
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
          <Route path="/workspace" element={<PlaceholderPage title="Workspace" />} />
          <Route path="/projects" element={<PlaceholderPage title="Projects" />} />
          <Route path="/skills" element={<PlaceholderPage title="Skills" />} />
          <Route path="/resources" element={<PlaceholderPage title="Resources" />} />
          <Route path="*" element={<Navigate to="/chat" replace />} />
        </Routes>
      </main>
    </div>
  );
}
