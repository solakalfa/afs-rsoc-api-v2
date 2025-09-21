export function jitter(ms: number): number {
  const delta = Math.floor(ms * 0.2);
  return ms + Math.floor(Math.random() * (2 * delta + 1)) - delta;
}

export function linearBackoff(attempt: number, baseMs = 2000): number {
  // attempt starts at 1
  return jitter(baseMs * attempt);
}

export function shouldRetry(status: number | undefined): boolean {
  if (!status) return true; // network/timeouts → retry
  if (status >= 500) return true;
  if (status === 429) return true;
  // Non-retryable (validation, auth, etc.)
  return false;
}
