export async function withRetry(fn, { attempts = 3, baseMs = 200 } = {}) {
  let last;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      await new Promise(r => setTimeout(r, baseMs * Math.pow(2, i)));
    }
  }
  throw last;
}
