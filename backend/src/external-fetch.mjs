import { logError, logEvent } from './observability.mjs';

export async function fetchTextWithTimeoutAndRetry(url, options = {}, config = {}) {
  const response = await fetchWithTimeoutAndRetry(url, options, config);
  return response;
}

export async function fetchJsonWithTimeoutAndRetry(url, options = {}, config = {}) {
  const response = await fetchWithTimeoutAndRetry(url, options, config);
  return {
    ...response,
    json: safeParseJson(response.text),
  };
}

async function fetchWithTimeoutAndRetry(url, options = {}, config = {}) {
  const label = config.label || 'external_request';
  const timeoutMs = Math.max(1, Number(config.timeoutMs ?? 10_000));
  const retries = Math.max(0, Number(config.retries ?? 0));
  let lastError;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const startedAt = Date.now();
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });
      const text = await response.text();
      const durationMs = Date.now() - startedAt;
      if (attempt < retries && shouldRetryExternalStatus(response.status)) {
        logEvent('warn', 'external_request_retry', {
          label,
          attempt: attempt + 1,
          status: response.status,
          ms: durationMs,
        });
        await sleep(backoffMs(attempt));
        continue;
      }
      logEvent(response.ok ? 'info' : 'warn', 'external_request', {
        label,
        status: response.status,
        ms: durationMs,
        attempt: attempt + 1,
      });
      return {
        ok: response.ok,
        status: response.status,
        headers: response.headers,
        text,
      };
    } catch (error) {
      lastError = error;
      clearTimeout(timeout);
      const durationMs = Date.now() - startedAt;
      if (attempt < retries) {
        logEvent('warn', 'external_request_retry', {
          label,
          attempt: attempt + 1,
          ms: durationMs,
          error: error.name === 'AbortError' ? 'timeout' : error.message,
        });
        await sleep(backoffMs(attempt));
        continue;
      }
      logError('external_request_failed', error, {
        label,
        attempt: attempt + 1,
        ms: durationMs,
      });
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  throw lastError ?? new Error(`${label}_failed`);
}

function safeParseJson(text) {
  try {
    return text ? JSON.parse(text) : {};
  } catch (_) {
    return {};
  }
}

function shouldRetryExternalStatus(status) {
  return status === 408 || status === 429 || status >= 500;
}

function backoffMs(attempt) {
  return Math.min(1000, 150 * 2 ** attempt);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
