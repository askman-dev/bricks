import { FormEvent, useEffect, useState } from 'react';
import { apiGet, apiPost, apiPut, apiDelete } from '../lib/api';

type Provider = 'anthropic' | 'google_ai_studio';

interface ModelPreferences {
  default_model: string;
  models?: string[];
}

interface ApiConfigData {
  slot_id?: string;
  endpoint?: string;
  api_key?: string;
  model_preferences?: ModelPreferences;
}

interface ApiConfig {
  id: string;
  category: string;
  provider: Provider;
  config: ApiConfigData;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

const PROVIDER_DEFAULTS: Record<Provider, { baseUrl: string; model: string }> = {
  anthropic: {
    baseUrl: 'https://api.anthropic.com',
    model: 'claude-sonnet-4-5',
  },
  google_ai_studio: {
    baseUrl: 'https://generativelanguage.googleapis.com',
    model: 'gemini-flash-latest',
  },
};

function toSlotId(model: string): string {
  return model
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || `slot-${Date.now()}`;
}

export function ModelSettingsPage() {
  const [configs, setConfigs] = useState<ApiConfig[]>([]);
  const [activeIdx, setActiveIdx] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [showKey, setShowKey] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [provider, setProvider] = useState<Provider>('anthropic');
  const [baseUrl, setBaseUrl] = useState(PROVIDER_DEFAULTS.anthropic.baseUrl);
  const [apiKey, setApiKey] = useState('');
  const [defaultModel, setDefaultModel] = useState(PROVIDER_DEFAULTS.anthropic.model);

  useEffect(() => {
    void loadConfigs();
  }, []);

  async function loadConfigs() {
    setLoading(true);
    setError(null);
    try {
      const data = await apiGet<ApiConfig[]>('/api/config?category=llm');
      const sorted = [...data].sort((a, b) => (b.is_default ? 1 : 0) - (a.is_default ? 1 : 0));
      if (sorted.length === 0) {
        setConfigs([]);
        resetFormToDefaults('anthropic');
      } else {
        setConfigs(sorted);
        const defIdx = sorted.findIndex((c) => c.is_default);
        const idx = defIdx >= 0 ? defIdx : 0;
        setActiveIdx(idx);
        hydrateForm(sorted[idx]);
      }
    } catch (err) {
      console.error('Failed to load model settings:', err);
      setError('Failed to load model settings');
    } finally {
      setLoading(false);
    }
  }

  function hydrateForm(config: ApiConfig) {
    const p = (config.provider ?? 'anthropic') as Provider;
    setProvider(p);
    setBaseUrl(config.config?.endpoint ?? PROVIDER_DEFAULTS[p].baseUrl);
    setApiKey('');
    setDefaultModel(
      config.config?.model_preferences?.default_model ?? PROVIDER_DEFAULTS[p].model,
    );
  }

  function resetFormToDefaults(p: Provider) {
    setProvider(p);
    setBaseUrl(PROVIDER_DEFAULTS[p].baseUrl);
    setApiKey('');
    setDefaultModel(PROVIDER_DEFAULTS[p].model);
  }

  function handleProviderChange(newProvider: Provider) {
    setProvider(newProvider);
    setBaseUrl(PROVIDER_DEFAULTS[newProvider].baseUrl);
    setDefaultModel(PROVIDER_DEFAULTS[newProvider].model);
  }

  async function handleSave(e: FormEvent) {
    e.preventDefault();
    const modelTrimmed = defaultModel.trim();
    if (!modelTrimmed) {
      setError('Default model is required');
      return;
    }
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const configPayload: ApiConfigData = {
        slot_id: toSlotId(modelTrimmed),
        endpoint: baseUrl.trim(),
        model_preferences: { default_model: modelTrimmed },
      };
      if (apiKey.trim()) configPayload.api_key = apiKey.trim();

      const active = configs[activeIdx];
      let saved: ApiConfig;
      if (!active?.id) {
        saved = await apiPost<ApiConfig>('/api/config', {
          category: 'llm',
          provider,
          config: configPayload,
          is_default: true,
        });
      } else {
        saved = await apiPut<ApiConfig>(`/api/config/${active.id}`, {
          category: 'llm',
          provider,
          config: configPayload,
          is_default: active.is_default,
        });
      }
      const updated = [...configs];
      if (!active?.id) {
        updated.push(saved);
        setActiveIdx(updated.length - 1);
      } else {
        updated[activeIdx] = saved;
      }
      setConfigs(updated);
      setSuccess('Model settings saved');
      setApiKey('');
    } catch (err) {
      console.error('Failed to save model settings:', err);
      setError('Failed to save model settings');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    const active = configs[activeIdx];
    if (!active?.id) return;
    if (!confirm('Delete this configuration?')) return;
    setDeleting(true);
    setError(null);
    setSuccess(null);
    try {
      await apiDelete(`/api/config/${active.id}`);
      await loadConfigs();
      setSuccess('Configuration deleted');
    } catch (err) {
      console.error('Failed to delete model config:', err);
      setError('Failed to delete configuration');
    } finally {
      setDeleting(false);
    }
  }

  if (loading) {
    return (
      <section className="page-panel">
        <p>Loading...</p>
      </section>
    );
  }

  const hasExisting = configs.length > 0 && !!configs[activeIdx]?.id;

  return (
    <section className="page-panel">
      <h2>Model Settings</h2>
      <p className="page-subtitle">Configure your LLM provider, API key, and default model.</p>

      {configs.length > 1 && (
        <div className="form-row">
          <label htmlFor="config-select">Configuration</label>
          <select
            id="config-select"
            value={activeIdx}
            onChange={(e) => {
              const idx = Number(e.target.value);
              setActiveIdx(idx);
              hydrateForm(configs[idx]);
              setError(null);
              setSuccess(null);
            }}
          >
            {configs.map((c, i) => (
              <option key={c.id || i} value={i}>
                {c.config?.model_preferences?.default_model ?? `Config ${i + 1}`}
                {c.is_default ? ' (default)' : ''}
              </option>
            ))}
          </select>
        </div>
      )}

      <form className="settings-form" onSubmit={(e) => void handleSave(e)}>
        <div className="form-row">
          <label htmlFor="provider">Provider</label>
          <select
            id="provider"
            value={provider}
            onChange={(e) => handleProviderChange(e.target.value as Provider)}
          >
            <option value="anthropic">Anthropic</option>
            <option value="google_ai_studio">Google AI Studio</option>
          </select>
        </div>

        <div className="form-row">
          <label htmlFor="base-url">Base URL</label>
          <input
            id="base-url"
            type="url"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            required
          />
        </div>

        <div className="form-row">
          <label htmlFor="api-key">API Key</label>
          <div className="input-group">
            <input
              id="api-key"
              type={showKey ? 'text' : 'password'}
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder={hasExisting ? '(unchanged – enter to update)' : 'Enter API key'}
              autoComplete="off"
            />
            <button
              type="button"
              className="toggle-btn"
              onClick={() => setShowKey((v) => !v)}
              aria-label={showKey ? 'Hide API key' : 'Show API key'}
            >
              {showKey ? 'Hide' : 'Show'}
            </button>
          </div>
        </div>

        <div className="form-row">
          <label htmlFor="default-model">Default Model</label>
          <input
            id="default-model"
            type="text"
            value={defaultModel}
            onChange={(e) => setDefaultModel(e.target.value)}
            required
          />
        </div>

        {error && <p className="form-feedback form-feedback--error">{error}</p>}
        {success && <p className="form-feedback form-feedback--success">{success}</p>}

        <div className="form-actions">
          <button type="submit" disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </button>
          {hasExisting && (
            <button
              type="button"
              className="danger-btn"
              disabled={deleting}
              onClick={() => void handleDelete()}
            >
              {deleting ? 'Deleting…' : 'Delete'}
            </button>
          )}
        </div>
      </form>
    </section>
  );
}
