import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { App } from '../App';

function mockFetch(sequence: Array<{ ok: boolean; json: unknown }>) {
  let index = 0;
  vi.spyOn(globalThis, 'fetch').mockImplementation(async () => {
    const current = sequence[Math.min(index, sequence.length - 1)];
    index += 1;
    return {
      ok: current.ok,
      json: async () => current.json,
    } as Response;
  });
}

afterEach(() => {
  vi.restoreAllMocks();
});

test('shows login entry when user is not authenticated', async () => {
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
  mockFetch([{ ok: true, json: { id: 'u1', email: 'demo@example.com' } }]);
  render(
    <MemoryRouter initialEntries={['/workspace']}>
      <App />
    </MemoryRouter>,
  );
  await waitFor(() => expect(screen.getByRole('heading', { name: 'Workspace' })).toBeInTheDocument());
  expect(screen.getByRole('link', { name: 'Chat' })).toBeInTheDocument();
});

test('sends chat message and displays assistant reply', async () => {
  const user = userEvent.setup();
  mockFetch([
    { ok: true, json: { id: 'u1', email: 'demo@example.com' } },
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
