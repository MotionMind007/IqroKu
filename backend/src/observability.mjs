export function logRequest({ requestId, method, path, status, ms, ip, error }) {
  logEvent(status >= 500 ? 'error' : status >= 400 ? 'warn' : 'info', 'http_request', {
    requestId,
    method,
    path,
    status,
    ms,
    ip,
    ...(error ? { error } : {}),
  });
}

export function logError(event, error, fields = {}) {
  logEvent('error', event, {
    ...fields,
    error: error?.message ?? String(error),
    stack: process.env.NODE_ENV === 'production' ? undefined : error?.stack,
  });
}

export function logEvent(level, event, fields = {}) {
  const payload = compactObject({
    ts: new Date().toISOString(),
    level,
    event,
    ...fields,
  });
  const line = JSON.stringify(payload);
  if (level === 'error') {
    console.error(line);
    return;
  }
  console.log(line);
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  );
}
