const SENSITIVE_KEY_PATTERN =
  /password|token|secret|authorization|jwt|api[-_]?key|cardnumber|cvv|refresh/i;

const MAX_STRING_LENGTH = 500;
const MAX_ARRAY_ITEMS = 20;
const MAX_DEPTH = 8;

/**
 * Strips credentials/secrets recursively and caps string/array size so a
 * single logged request body cannot leak sensitive data or blow up the log file.
 */
export function redactSensitiveData(value: unknown, depth = 0): unknown {
  if (depth > MAX_DEPTH) {
    return '[truncated]';
  }

  if (typeof value === 'string') {
    return value.length > MAX_STRING_LENGTH
      ? `${value.slice(0, MAX_STRING_LENGTH)}...[truncated]`
      : value;
  }

  if (Array.isArray(value)) {
    return value
      .slice(0, MAX_ARRAY_ITEMS)
      .map((item) => redactSensitiveData(item, depth + 1));
  }

  if (value !== null && typeof value === 'object') {
    const redacted: Record<string, unknown> = {};
    for (const [key, entryValue] of Object.entries(
      value as Record<string, unknown>,
    )) {
      redacted[key] = SENSITIVE_KEY_PATTERN.test(key)
        ? '[redacted]'
        : redactSensitiveData(entryValue, depth + 1);
    }
    return redacted;
  }

  return value;
}
