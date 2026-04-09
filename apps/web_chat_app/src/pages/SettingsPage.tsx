import { NavLink, useNavigate } from 'react-router-dom';
import { clearAuthToken } from '../lib/api';

export function SettingsPage() {
  const navigate = useNavigate();

  function handleSignOut() {
    if (!confirm('Are you sure you want to sign out?')) return;
    clearAuthToken();
    window.location.replace('/');
  }

  return (
    <section className="settings-mobile-page">
      <header className="settings-mobile-header">
        <button type="button" className="icon-btn" aria-label="Back" onClick={() => navigate('/chat')}>
          ←
        </button>
        <h1>Settings</h1>
      </header>

      <ul className="settings-mobile-list">
        <li>
          <NavLink to="/settings/model" className="settings-mobile-item">
            <span className="settings-mobile-icon">☷</span>
            <div>
              <strong>Model Settings</strong>
              <p>Provider, Base URL, API Key</p>
            </div>
          </NavLink>
        </li>
        <li>
          <button type="button" className="settings-mobile-item">
            <span className="settings-mobile-icon">◫</span>
            <div>
              <strong>Manage Agents</strong>
              <p>Create and edit agent definitions</p>
            </div>
          </button>
        </li>
        <li>
          <button className="settings-mobile-item" type="button" onClick={handleSignOut}>
            <span className="settings-mobile-icon">⇥</span>
            <div>
              <strong>Sign Out</strong>
            </div>
          </button>
        </li>
      </ul>
    </section>
  );
}
