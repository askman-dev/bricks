export function sanitizeTableCellData(raw: unknown): Record<string, string | null> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const result: Record<string, string | null> = {};
  for (const [key, val] of Object.entries(raw as Record<string, unknown>)) {
    if (val === null || val === undefined) {
      result[key] = null;
    } else if (typeof val === 'string') {
      result[key] = val;
    } else if (typeof val === 'number' || typeof val === 'boolean') {
      result[key] = String(val);
    }
  }
  return result;
}

export function sanitizeBatchRowCellData(raw: unknown): Record<string, string | null> {
  if (raw && typeof raw === 'object' && !Array.isArray(raw) && 'cellData' in raw) {
    return sanitizeTableCellData((raw as { cellData?: unknown }).cellData);
  }
  return sanitizeTableCellData(raw);
}
