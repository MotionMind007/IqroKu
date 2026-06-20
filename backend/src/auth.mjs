import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

export function createAuthServices({
  config,
  db,
  fetchTextWithTimeoutAndRetry,
  httpError,
  addMinutes,
  escapeHtml,
  formatDateTime,
  logError,
  logEvent,
}) {
  async function authenticateRequest(request) {
    const authHeader = request.headers?.['authorization'] ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7).trim()
      : '';

    if (!token) {
      throw httpError(401, 'missing_auth_token');
    }

    const parentId = await db.resolveSession(token);
    if (parentId) {
      const parent = await db.findParentById(parentId);
      if (parent) {
        return parent;
      }
    }

    throw httpError(401, 'invalid_auth_token');
  }

  async function storeSession(token, parentId) {
    await db.createSession(token, parentId);
  }

  async function revokeSession(token) {
    await db.deleteSession(token);
  }

  async function verifyGoogleIdToken(idToken) {
    if (!idToken) {
      throw httpError(400, 'missing_id_token');
    }
    let payload;
    try {
      const res = await fetchTextWithTimeoutAndRetry(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
        {},
        {
          label: 'google_tokeninfo',
          timeoutMs: config.googleVerifyTimeoutMs,
          retries: config.googleVerifyRetries,
        },
      );
      if (!res.ok) {
        throw httpError(401, 'invalid_google_token');
      }
      payload = JSON.parse(res.text || '{}');
    } catch (err) {
      if (err.statusCode) throw err;
      throw httpError(502, 'google_verification_failed');
    }

    if (payload.aud !== config.googleClientId) {
      throw httpError(401, 'google_token_wrong_audience');
    }
    if (payload.iss !== 'accounts.google.com' && payload.iss !== 'https://accounts.google.com') {
      throw httpError(401, 'google_token_wrong_issuer');
    }
    if (payload.exp && Number(payload.exp) * 1000 < Date.now()) {
      throw httpError(401, 'google_token_expired');
    }
    if (!payload.email || payload.email_verified === 'false' || payload.email_verified === false) {
      throw httpError(401, 'google_email_unverified');
    }
    return { email: String(payload.email), sub: String(payload.sub), name: payload.name };
  }

  function validatePassword(password) {
    if (password.length < 6) {
      throw httpError(400, 'password_min_6');
    }
    if (password.length > 128) {
      throw httpError(400, 'password_too_long');
    }
  }

  function hashPassword(password) {
    const salt = randomBytes(16).toString('hex');
    const hash = scryptSync(password, salt, 64).toString('hex');
    return `scrypt:${salt}:${hash}`;
  }

  function verifyPassword(password, encoded) {
    const [scheme, salt, expectedHex] = String(encoded).split(':');
    if (scheme !== 'scrypt' || !salt || !expectedHex) {
      return false;
    }
    const expected = Buffer.from(expectedHex, 'hex');
    const actual = scryptSync(password, salt, expected.length);
    return expected.length === actual.length && timingSafeEqual(expected, actual);
  }

  function createSessionToken() {
    return `session_${randomBytes(32).toString('base64url')}`;
  }

  async function createAuthFlowToken(parent, purpose, ttlMinutes) {
    const token = createOneTimeToken();
    const expiresAt = addMinutes(new Date(), ttlMinutes).toISOString();
    await db.createAuthToken({
      parentId: parent.id,
      purpose,
      tokenHash: hashAuthToken(token),
      expiresAt,
      metadata: { email: parent.email },
    });
    return { token, expiresAt };
  }

  async function consumeAuthFlowToken(purpose, token) {
    const record = await db.findValidAuthToken({
      purpose,
      tokenHash: hashAuthToken(token),
    });
    if (!record) {
      throw httpError(400, 'invalid_or_expired_token');
    }
    await db.markAuthTokenUsed(record.id);
    const parent = await db.findParentById(record.parentId);
    if (!parent) {
      throw httpError(400, 'invalid_or_expired_token');
    }
    return parent;
  }

  function authFlowResponse(flow, extra = {}) {
    return {
      ...extra,
      expiresAt: flow.expiresAt,
      devToken: process.env.NODE_ENV === 'production' ? undefined : flow.token,
    };
  }

  async function sendAuthFlowEmail({ type, email, token, expiresAt, path }) {
    const link = `${config.authLinkBaseUrl.replace(/\/$/, '')}${path}?token=${encodeURIComponent(token)}`;
    const message = authEmailMessage({ type, token, expiresAt, link });
    const configured = config.emailProvider === 'resend' && config.resendApiKey && config.emailFrom;
    if (!configured) {
      logAuthFlowToken({
        type,
        email,
        token,
        link,
        delivery: config.emailProvider === 'none'
          ? 'email_provider_not_configured'
          : 'email_provider_incomplete',
      });
      return;
    }

    try {
      await sendResendEmail({
        to: email,
        subject: message.subject,
        html: message.html,
        text: message.text,
      });
      logEvent('info', 'auth_email_sent', {
        provider: config.emailProvider,
        type,
        email,
      });
    } catch (error) {
      logError('auth_email_failed', error, {
        provider: config.emailProvider,
        type,
        email,
      });
    }
  }

  return {
    authenticateRequest,
    authFlowResponse,
    consumeAuthFlowToken,
    createAuthFlowToken,
    createSessionToken,
    hashPassword,
    revokeSession,
    sendAuthFlowEmail,
    storeSession,
    validatePassword,
    verifyGoogleIdToken,
    verifyPassword,
  };

  function createOneTimeToken() {
    return randomBytes(32).toString('base64url');
  }

  function hashAuthToken(token) {
    return createHash('sha256').update(String(token)).digest('hex');
  }

  function logAuthFlowToken({ type, email, token, link, delivery }) {
    const payload = {
      type,
      email,
      delivery,
    };
    if (process.env.NODE_ENV !== 'production') {
      payload.token = token;
      payload.link = link;
    }
    logEvent('info', 'auth_token_created', payload);
  }

  function authEmailMessage({ type, token, expiresAt, link }) {
    const isReset = type === 'password_reset';
    const title = isReset ? 'Reset Password IqroKu' : 'Verifikasi Email IqroKu';
    const intro = isReset
      ? 'Gunakan kode di bawah ini untuk mengatur ulang password akun IqroKu.'
      : 'Gunakan kode di bawah ini untuk memverifikasi email akun IqroKu.';
    const outro = isReset
      ? 'Abaikan email ini jika kamu tidak meminta reset password.'
      : 'Abaikan email ini jika kamu tidak membuat akun IqroKu.';
    const expiry = formatDateTime(expiresAt);
    return {
      subject: title,
      text: `${intro}\n\nKode: ${token}\nBerlaku sampai: ${expiry}\n\n${outro}`,
      html: `<!doctype html>
<html lang="id">
  <body style="margin:0;padding:24px;background:#f8f6ef;color:#17201b;font-family:Arial,sans-serif;">
    <div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #e7e1d6;border-radius:16px;padding:24px;">
      <h1 style="margin:0 0 12px;font-size:24px;color:#0f5b39;">${escapeHtml(title)}</h1>
      <p style="margin:0 0 18px;font-size:15px;line-height:1.5;">${escapeHtml(intro)}</p>
      <div style="font-size:22px;font-weight:800;letter-spacing:2px;background:#e7f5ec;color:#0f5b39;border-radius:12px;padding:16px;text-align:center;word-break:break-all;">
        ${escapeHtml(token)}
      </div>
      <p style="margin:18px 0 0;font-size:13px;color:#6d756f;">Berlaku sampai: ${escapeHtml(expiry)}</p>
      <p style="margin:10px 0 0;font-size:13px;color:#6d756f;">${escapeHtml(outro)}</p>
      <p style="margin:18px 0 0;font-size:12px;color:#6d756f;">Link teknis: ${escapeHtml(link)}</p>
    </div>
  </body>
</html>`,
    };
  }

  async function sendResendEmail({ to, subject, html, text }) {
    const response = await fetchTextWithTimeoutAndRetry('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'authorization': `Bearer ${config.resendApiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          from: config.emailFrom,
          to: [to],
          subject,
          html,
          text,
          ...(config.emailReplyTo ? { reply_to: config.emailReplyTo } : {}),
        }),
      },
      {
        label: 'resend_email',
        timeoutMs: config.emailSendTimeoutMs,
        retries: config.emailSendRetries,
      });
    if (!response.ok) {
      throw new Error(`resend_${response.status}${response.text ? `: ${response.text.slice(0, 200)}` : ''}`);
    }
  }
}
