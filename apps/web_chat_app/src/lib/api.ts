const AUTH_TOKEN_KEY = 'auth_token';

export function getAuthToken(): string | null {
  return localStorage.getItem(AUTH_TOKEN_KEY);
}

export function setAuthToken(token: string): void {
  localStorage.setItem(AUTH_TOKEN_KEY, token);
}

export function clearAuthToken(): void {
  localStorage.removeItem(AUTH_TOKEN_KEY);
}

function authHeaders(): Record<string, string> {
  const token = getAuthToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export async function apiGet<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    credentials: 'include',
    headers: authHeaders(),
  });
  if (!response.ok) throw new Error(`GET ${url} failed`);
  return response.json() as Promise<T>;
}

export async function apiPost<T>(url: string, body: unknown): Promise<T> {
  const response = await fetch(url, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`POST ${url} failed`);
  return response.json() as Promise<T>;
}

export async function apiPut<T>(url: string, body: unknown): Promise<T> {
  const response = await fetch(url, {
    method: 'PUT',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`PUT ${url} failed`);
  return response.json() as Promise<T>;
}

export async function apiDelete(url: string): Promise<void> {
  const response = await fetch(url, {
    method: 'DELETE',
    credentials: 'include',
    headers: authHeaders(),
  });
  if (!response.ok) throw new Error(`DELETE ${url} failed`);
}
