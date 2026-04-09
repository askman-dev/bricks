import { NavLink } from 'react-router-dom';
import { clearAuthToken } from '../lib/api';

export function SettingsPage() {
  function handleSignOut() {
    if (!confirm('Are you sure you want to sign out?')) return;
    clearAuthToken();
    window.location.replace('/');
  }

  return (
    <section className="page-panel settings-page">
      <h2>Settings</h2>
      <ul className="settings-list">
        <li>
          <NavLink to="/settings/model" className="settings-link">
            <span className="settings-icon">⚙️</span>
            <div>
              <strong>Model Settings</strong>
              <p>Provider, Base URL, API Key</p>
            </div>
          </NavLink>
        </li>
        <li>
          <button className="settings-link settings-link--danger" onClick={handleSignOut}>
            <span className="settings-icon">🚪</span>
            <div>
              <strong>Sign Out</strong>
              <p>Clear credentials and return to login</p>
            </div>
          </button>
        </li>
      </ul>
    </section>
  );
}
