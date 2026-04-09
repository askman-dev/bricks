import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { App } from '../App';

const TEST_TOKEN = 'test-jwt-token';

/** Mock fetch with a fixed sequence of responses; captures call arguments. */
function mockFetch(sequence: Array<{ ok: boolean; json: unknown }>) {
  let index = 0;
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async () => {
    const current = sequence[Math.min(index, sequence.length - 1)];
    index += 1;
    return {
      ok: current.ok,
      json: async () => current.json,
    } as Response;
  });
}

beforeEach(() => {
  localStorage.setItem('auth_token', TEST_TOKEN);
});

afterEach(() => {
  localStorage.removeItem('auth_token');
  vi.restoreAllMocks();
});

test('shows login entry when user is not authenticated', async () => {
  localStorage.removeItem('auth_token');
  mockFetch([{ ok: false, json: {} }]);
  render(
    <MemoryRouter>
      <App />
    </MemoryRouter>,
  );
  await waitFor(() => {
    expect(screen.getByText('Login with GitHub')).toBeInTheDocument();
  });
});

test('renders mobile chat shell after auth on /chat', async () => {
  const fetchSpy = mockFetch([
    {
      ok: true,
      json: {
        user: { id: 'u1', email: 'demo@example.com', created_at: '2024-01-01', updated_at: '2024-01-01' },
        oauth_connections: [],
      },
    },
  ]);
  render(
    <MemoryRouter initialEntries={['/chat']}>
      <App />
    </MemoryRouter>,
  );

  await waitFor(() => expect(screen.getByRole('heading', { name: 'Bricks' })).toBeInTheDocument());
  expect(screen.getByRole('button', { name: 'Open navigation menu' })).toBeInTheDocument();

  // Verify Authorization header is sent with the stored JWT
  const firstCall = fetchSpy.mock.calls[0];
  const options = firstCall?.[1] as RequestInit | undefined;
  const headers = options?.headers as Record<string, string> | undefined;
  expect(headers?.Authorization).toBe(`Bearer ${TEST_TOKEN}`);
});

test('sends chat message and displays assistant reply', async () => {
  const user = userEvent.setup();
  mockFetch([
    {
      ok: true,
      json: {
        user: { id: 'u1', email: 'demo@example.com', created_at: '2024-01-01', updated_at: '2024-01-01' },
        oauth_connections: [],
      },
    },
    { ok: true, json: { text: 'Hello from assistant' } },
  ]);
  render(
    <MemoryRouter initialEntries={['/chat']}>
      <App />
    </MemoryRouter>,
  );

  await waitFor(() => {
    expect(screen.getByPlaceholderText('Ask Bricks to create something...')).toBeInTheDocument();
  });

  await user.type(screen.getByPlaceholderText('Ask Bricks to create something...'), 'Hi');
  await user.click(screen.getByRole('button', { name: 'Send message' }));

  await waitFor(() => {
    expect(screen.getByText(/Hello from assistant/)).toBeInTheDocument();
  });
});

test('mobile drawer matches navigation groups with agents and channels', async () => {
  const user = userEvent.setup();
  mockFetch([
    {
      ok: true,
      json: {
        user: { id: 'u1', email: 'demo@example.com', created_at: '2024-01-01', updated_at: '2024-01-01' },
        oauth_connections: [],
      },
    },
    { ok: true, json: [] },
  ]);
  render(
    <MemoryRouter initialEntries={['/chat']}>
      <App />
    </MemoryRouter>,
  );

  await waitFor(() => {
    expect(screen.getByRole('button', { name: 'Open navigation menu' })).toBeInTheDocument();
  });

  await user.click(screen.getByRole('button', { name: 'Open navigation menu' }));

  expect(screen.getByRole('heading', { name: 'Navigation' })).toBeInTheDocument();
  expect(screen.getByText('Current Chat')).toBeInTheDocument();
  expect(screen.getByRole('button', { name: 'Agents section' })).toBeInTheDocument();
  expect(screen.getByRole('button', { name: 'Channels section' })).toBeInTheDocument();
  expect(screen.getByText('默认频道')).toBeInTheDocument();
});
