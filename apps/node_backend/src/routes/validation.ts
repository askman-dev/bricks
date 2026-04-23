export const OUTPUT_TOKENS_LIMIT = 120 * 1024;
export const DEFAULT_MAX_OUTPUT_TOKENS = OUTPUT_TOKENS_LIMIT;
export const MAX_OUTPUT_TOKENS_UPPER_BOUND = OUTPUT_TOKENS_LIMIT;

export function parseMaxTokens(
  value: unknown,
): { ok: true; value: number } | { ok: false; error: string } {
  if (value === undefined || value === null) {
    return { ok: true, value: DEFAULT_MAX_OUTPUT_TOKENS };
  }
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    return { ok: false, error: 'maxTokens must be a positive integer' };
  }
  if (value > MAX_OUTPUT_TOKENS_UPPER_BOUND) {
    return {
      ok: false,
      error: `maxTokens must be <= ${MAX_OUTPUT_TOKENS_UPPER_BOUND}`,
    };
  }
  return { ok: true, value };
}
