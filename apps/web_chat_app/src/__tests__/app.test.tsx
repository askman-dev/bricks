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

test('renders sidebar after auth and routes to chat', async () => {
  const fetchSpy = mockFetch([
    { ok: true, json: { user: { id: 'u1', email: 'demo@example.com', created_at: '2024-01-01', updated_at: '2024-01-01' }, oauth_connections: [] } },
  ]);
  render(
    <MemoryRouter initialEntries={['/workspace']}>
      <App />
    </MemoryRouter>,
  );
  await waitFor(() => expect(screen.getByRole('heading', { name: 'Workspace' })).toBeInTheDocument());
  expect(screen.getByRole('link', { name: 'Chat' })).toBeInTheDocument();

  // Verify Authorization header is sent with the stored JWT
  const firstCall = fetchSpy.mock.calls[0];
  const options = firstCall?.[1] as RequestInit | undefined;
  const headers = options?.headers as Record<string, string> | undefined;
  expect(headers?.['Authorization']).toBe(`Bearer ${TEST_TOKEN}`);
});

test('sends chat message and displays assistant reply', async () => {
  const user = userEvent.setup();
  mockFetch([
    { ok: true, json: { user: { id: 'u1', email: 'demo@example.com', created_at: '2024-01-01', updated_at: '2024-01-01' }, oauth_connections: [] } },
    { ok: true, json: { text: 'Hello from assistant' } },
  ]);
  render(
    <MemoryRouter initialEntries={['/chat']}>
      <App />
    </MemoryRouter>,
  );

  await waitFor(() => expect(screen.getByText('Conversation')).toBeInTheDocument());
  await user.type(screen.getByPlaceholderText('Type your message'), 'Hi');
  await user.click(screen.getByRole('button', { name: 'Send' }));

  await waitFor(() => {
    expect(screen.getByText(/Hello from assistant/)).toBeInTheDocument();
  });
});
