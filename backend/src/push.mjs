import { createSign } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fetchJsonWithTimeoutAndRetry } from './external-fetch.mjs';
import { logEvent } from './observability.mjs';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SEND_TIMEOUT_MS = Number(process.env.FCM_SEND_TIMEOUT_MS ?? 10_000);
const FCM_SEND_RETRIES = Number(process.env.FCM_SEND_RETRIES ?? 2);
const FCM_OAUTH_TIMEOUT_MS = Number(process.env.FCM_OAUTH_TIMEOUT_MS ?? 10_000);
const FCM_OAUTH_RETRIES = Number(process.env.FCM_OAUTH_RETRIES ?? 2);

let serviceAccountPromise;
let accessTokenCache;

export function pushConfigured() {
  return Boolean(
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS,
  );
}

export async function sendPushToTokens({ tokens, title, body, data }) {
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  if (uniqueTokens.length === 0) {
    return { sent: 0, failed: 0, invalidTokens: [] };
  }
  if (!pushConfigured()) {
    logEvent('info', 'fcm_push_skipped', { reason: 'firebase_service_account_not_configured' });
    return { sent: 0, failed: 0, invalidTokens: [] };
  }

  const serviceAccount = await loadServiceAccount();
  const accessToken = await getAccessToken(serviceAccount);
  const projectId = serviceAccount.project_id || process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID or service account project_id is required.');
  }

  const invalidTokens = [];
  let sent = 0;
  let failed = 0;

  for (const token of uniqueTokens) {
    const response = await fetchJsonWithTimeoutAndRetry(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: stringifyData(data),
            android: {
              priority: 'HIGH',
              notification: { sound: 'default' },
            },
          },
        }),
      },
      {
        label: 'fcm_message_send',
        timeoutMs: FCM_SEND_TIMEOUT_MS,
        retries: FCM_SEND_RETRIES,
      },
    );

    if (response.ok) {
      sent += 1;
      continue;
    }

    failed += 1;
    const error = response.json ?? {};
    if (isInvalidTokenError(response.status, error)) {
      invalidTokens.push(token);
      continue;
    }
    logEvent('error', 'fcm_push_failed', { status: response.status, error });
  }

  return { sent, failed, invalidTokens };
}

async function loadServiceAccount() {
  serviceAccountPromise ??= (async () => {
    const rawJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (rawJson) {
      return normalizeServiceAccount(JSON.parse(rawJson));
    }

    const path =
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!path) {
      throw new Error('Firebase service account env is not configured.');
    }
    const content = await readFile(path, 'utf8');
    return normalizeServiceAccount(JSON.parse(content));
  })();
  return serviceAccountPromise;
}

function normalizeServiceAccount(account) {
  if (!account.client_email || !account.private_key) {
    throw new Error('Firebase service account must include client_email and private_key.');
  }
  return {
    ...account,
    private_key: String(account.private_key).replaceAll('\\n', '\n'),
  };
}

async function getAccessToken(serviceAccount) {
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (accessTokenCache && accessTokenCache.expiresAtSeconds - 60 > nowSeconds) {
    return accessTokenCache.token;
  }

  const assertion = signJwt({
    clientEmail: serviceAccount.client_email,
    privateKey: serviceAccount.private_key,
    issuedAtSeconds: nowSeconds,
  });
  const response = await fetchJsonWithTimeoutAndRetry(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  }, {
    label: 'fcm_oauth_token',
    timeoutMs: FCM_OAUTH_TIMEOUT_MS,
    retries: FCM_OAUTH_RETRIES,
  });
  const json = response.json ?? {};
  if (!response.ok) {
    throw new Error(`Firebase OAuth token request failed: ${JSON.stringify(json)}`);
  }

  accessTokenCache = {
    token: json.access_token,
    expiresAtSeconds: nowSeconds + Number(json.expires_in ?? 3600),
  };
  return accessTokenCache.token;
}

function signJwt({ clientEmail, privateKey, issuedAtSeconds }) {
  const header = base64UrlJson({ alg: 'RS256', typ: 'JWT' });
  const payload = base64UrlJson({
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: issuedAtSeconds,
    exp: issuedAtSeconds + 3600,
  });
  const unsignedToken = `${header}.${payload}`;
  const signature = createSign('RSA-SHA256').update(unsignedToken).sign(privateKey);
  return `${unsignedToken}.${base64Url(signature)}`;
}

function base64UrlJson(value) {
  return base64Url(Buffer.from(JSON.stringify(value)));
}

function base64Url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function stringifyData(data) {
  if (!data || typeof data !== 'object') {
    return {};
  }
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, typeof value === 'string' ? value : JSON.stringify(value)]),
  );
}

function isInvalidTokenError(status, error) {
  if (status === 404) {
    return true;
  }
  const text = JSON.stringify(error);
  return (
    text.includes('UNREGISTERED') ||
    text.includes('INVALID_ARGUMENT') ||
    text.includes('registration-token-not-registered')
  );
}
