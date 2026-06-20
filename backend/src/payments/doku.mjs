import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';

export const DOKU_PROVIDER = 'doku';
export const DOKU_CHECKOUT_PATH = '/checkout/v1/payment';
export const DOKU_WEBHOOK_PATH = '/payments/doku/webhook';

export function createDokuPayments({
  config,
  db,
  fetchTextWithTimeoutAndRetry,
  httpError,
  safeStrEqual,
  escapeHtml,
  optionalString,
  truncateString,
  addMinutes,
}) {
  async function createCheckout(parent) {
    assertConfigured();
    if (!Number.isInteger(config.checkoutAmount) || config.checkoutAmount <= 0) {
      throw httpError(500, 'payment_amount_invalid');
    }

    const invoiceNumber = createInvoiceNumber();
    const requestId = randomUUID();
    const expiresAt = addMinutes(new Date(), config.checkoutDueMinutes).toISOString();
    await db.createPaymentOrder({
      id: randomUUID(),
      parentId: parent.id,
      provider: DOKU_PROVIDER,
      invoiceNumber,
      requestId,
      plan: 'plus',
      amount: config.checkoutAmount,
      currency: 'IDR',
      status: 'pending',
      expiresAt,
    });

    const payload = buildCheckoutPayload({ parent, invoiceNumber });
    const rawBody = JSON.stringify(payload);
    let responsePayload;
    try {
      responsePayload = await sendRequest({
        requestId,
        targetPath: DOKU_CHECKOUT_PATH,
        rawBody,
      });
    } catch (error) {
      await db.updatePaymentOrderProviderResponse({
        invoiceNumber,
        status: 'failed',
        rawResponse: { error: error.message },
      });
      throw error;
    }

    const checkoutUrl = checkoutUrlFromPayload(responsePayload);
    if (!checkoutUrl) {
      await db.updatePaymentOrderProviderResponse({
        invoiceNumber,
        status: 'failed',
        rawResponse: responsePayload,
      });
      throw httpError(502, 'doku_checkout_url_missing');
    }

    const order = await db.updatePaymentOrderProviderResponse({
      invoiceNumber,
      checkoutUrl,
      providerOrderId: providerOrderId(responsePayload),
      rawResponse: responsePayload,
    });

    return {
      ok: true,
      checkoutUrl,
      payment: publicPaymentOrder(order),
    };
  }

  async function handleWebhook(body, request) {
    assertConfigured();
    verifySignature(request);

    const invoiceNumber = notificationInvoiceNumber(body);
    if (!invoiceNumber) {
      throw httpError(400, 'missing_invoice_number');
    }

    const requestId = requiredHeader(request, 'request-id');
    const order = await db.findPaymentOrderByInvoiceNumber(invoiceNumber);
    if (!order) {
      await db.recordPaymentEvent({
        provider: DOKU_PROVIDER,
        requestId,
        invoiceNumber,
        eventType: notificationEventType(body),
        signatureValid: true,
        payload: body,
      });
      throw httpError(404, 'payment_order_not_found');
    }

    const amount = notificationAmount(body);
    if (amount !== null && amount !== order.amount) {
      await db.recordPaymentEvent({
        provider: DOKU_PROVIDER,
        requestId,
        invoiceNumber,
        eventType: 'amount_mismatch',
        signatureValid: true,
        payload: body,
      });
      throw httpError(400, 'payment_amount_mismatch');
    }

    const result = await db.applyPaymentNotification({
      provider: DOKU_PROVIDER,
      requestId,
      invoiceNumber,
      eventType: notificationEventType(body),
      signatureValid: true,
      payload: body,
      status: notificationOrderStatus(body),
      paidAt: notificationPaidAt(body),
    });

    return {
      ok: true,
      duplicate: result.duplicate,
      payment: result.order ? publicPaymentOrder(result.order) : undefined,
    };
  }

  function assertConfigured() {
    if (!config.clientId || !config.secretKey) {
      throw httpError(503, 'payment_provider_not_configured');
    }
  }

  function buildCheckoutPayload({ parent, invoiceNumber }) {
    return {
      order: {
        amount: config.checkoutAmount,
        invoice_number: invoiceNumber,
        currency: 'IDR',
        callback_url: config.checkoutReturnUrl,
        callback_url_cancel: config.checkoutFailedUrl,
        callback_url_result: config.checkoutReturnUrl,
        auto_redirect: true,
        line_items: [
          {
            name: 'IqroKu Plus 1 Bulan',
            price: config.checkoutAmount,
            quantity: 1,
          },
        ],
      },
      payment: {
        payment_due_date: Math.max(1, Math.round(config.checkoutDueMinutes)),
      },
      customer: {
        id: parent.id,
        name: truncateString(parent.name || 'Orang Tua'),
        email: parent.email,
      },
      additional_info: {
        override_notification_url: config.notificationUrl,
        integration: {
          name: 'iqroku-backend',
          version: '0.2.0',
        },
      },
    };
  }

  async function sendRequest({ requestId, targetPath, rawBody }) {
    const timestamp = dokuTimestamp();
    const signature = dokuSignature({
      requestId,
      timestamp,
      targetPath,
      rawBody,
    });

    try {
      const response = await fetchTextWithTimeoutAndRetry(`${config.baseUrl}${targetPath}`, {
        method: 'POST',
        headers: {
          'client-id': config.clientId,
          'request-id': requestId,
          'request-timestamp': timestamp,
          'request-target': targetPath,
          'signature': signature,
          'content-type': 'application/json',
        },
        body: rawBody,
      }, {
        label: 'doku_checkout',
        timeoutMs: config.sendTimeoutMs,
        retries: config.sendRetries,
      });
      let payload;
      try {
        payload = response.text ? JSON.parse(response.text) : {};
      } catch (_) {
        payload = { raw: response.text };
      }
      if (!response.ok) {
        throw httpError(502, `doku_checkout_failed_${response.status}`);
      }
      return payload;
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      throw httpError(502, 'doku_checkout_request_failed');
    }
  }

  function verifySignature(request) {
    const clientId = requiredHeader(request, 'client-id');
    if (!safeStrEqual(clientId, config.clientId)) {
      throw httpError(401, 'invalid_doku_client_id');
    }
    const requestId = requiredHeader(request, 'request-id');
    const timestamp = requiredHeader(request, 'request-timestamp');
    const signature = requiredHeader(request, 'signature');
    const targetPath = optionalHeader(request, 'request-target')
      || new URL(request.url ?? DOKU_WEBHOOK_PATH, `http://${request.headers.host ?? 'localhost'}`).pathname;
    if (targetPath !== DOKU_WEBHOOK_PATH) {
      throw httpError(401, 'invalid_doku_request_target');
    }
    const parsedTimestamp = Date.parse(timestamp);
    if (!Number.isFinite(parsedTimestamp)) {
      throw httpError(401, 'invalid_doku_timestamp');
    }
    if (
      config.signatureToleranceMs > 0
      && Math.abs(Date.now() - parsedTimestamp) > config.signatureToleranceMs
    ) {
      throw httpError(401, 'stale_doku_signature');
    }
    if (typeof request.rawBody !== 'string') {
      throw httpError(400, 'missing_doku_raw_body');
    }
    const expected = dokuSignature({
      requestId,
      timestamp,
      targetPath,
      rawBody: request.rawBody,
    });
    if (!safeStrEqual(signature, expected)) {
      throw httpError(401, 'invalid_doku_signature');
    }
  }

  function dokuSignature({ requestId, timestamp, targetPath, rawBody }) {
    const digest = createHash('sha256').update(rawBody).digest('base64');
    const component = [
      `Client-Id:${config.clientId}`,
      `Request-Id:${requestId}`,
      `Request-Timestamp:${timestamp}`,
      `Request-Target:${targetPath}`,
      `Digest:${digest}`,
    ].join('\n');
    return `HMACSHA256=${createHmac('sha256', config.secretKey).update(component).digest('base64')}`;
  }

  function requiredHeader(request, key) {
    const normalized = optionalHeader(request, key);
    if (!normalized) {
      throw httpError(400, `missing_${key.replaceAll('-', '_')}`);
    }
    return normalized;
  }

  function optionalHeader(request, key) {
    const value = request.headers?.[key] ?? request.headers?.[key.toLowerCase()];
    return optionalString(Array.isArray(value) ? value[0] : value);
  }

  return {
    createCheckout,
    handleWebhook,
    publicPaymentOrder,
    renderRedirectPage,
  };

  function renderRedirectPage({ status, url }) {
    const success = status === 'success';
    const title = success ? 'Pembayaran Diproses' : 'Pembayaran Belum Berhasil';
    const message = success
      ? 'Terima kasih. Jika pembayaran sudah berhasil, status IqroKu Plus akan aktif setelah notifikasi DOKU diterima.'
      : 'Pembayaran belum selesai atau dibatalkan. Kamu bisa kembali ke aplikasi dan mencoba lagi.';
    const invoiceNumber = url.searchParams.get('invoice_number')
      || url.searchParams.get('invoiceNumber')
      || url.searchParams.get('order_id')
      || '';
    return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>${escapeHtml(title)} - IqroKu</title>
    <style>
      :root { color-scheme: light; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: #f8f6ef;
        color: #17201b;
        font-family: Arial, sans-serif;
      }
      main {
        width: min(420px, calc(100vw - 32px));
        background: #fff;
        border: 1px solid #e8e1d6;
        border-radius: 18px;
        padding: 24px;
        box-shadow: 0 16px 48px rgba(23, 32, 27, 0.08);
      }
      .badge {
        width: 52px;
        height: 52px;
        display: grid;
        place-items: center;
        border-radius: 999px;
        margin-bottom: 18px;
        color: #fff;
        background: ${success ? '#208c53' : '#c95f4b'};
        font-size: 28px;
        font-weight: 800;
      }
      h1 { margin: 0 0 10px; font-size: 26px; line-height: 1.15; }
      p { margin: 0 0 14px; color: #68716b; font-size: 15px; line-height: 1.5; }
      .invoice {
        margin-top: 16px;
        padding: 12px 14px;
        border-radius: 12px;
        background: #f2eee6;
        color: #17201b;
        font-size: 13px;
        word-break: break-all;
      }
      a {
        display: inline-block;
        margin-top: 10px;
        color: #208c53;
        font-weight: 700;
        text-decoration: none;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="badge">${success ? '&#10003;' : '!'}</div>
      <h1>${escapeHtml(title)}</h1>
      <p>${escapeHtml(message)}</p>
      <p>Kembali ke aplikasi IqroKu, lalu tarik layar untuk refresh jika status Plus belum berubah.</p>
      ${invoiceNumber ? `<div class="invoice">Invoice: ${escapeHtml(invoiceNumber)}</div>` : ''}
      <a href="/">Tutup halaman ini</a>
    </main>
  </body>
</html>`;
  }
}

function dokuTimestamp() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function createInvoiceNumber() {
  const stamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
  return `IQK${stamp}${randomBytes(4).toString('hex').toUpperCase()}`;
}

function checkoutUrlFromPayload(payload) {
  return optionalStringFromPayload(payload?.response?.payment?.url)
    || optionalStringFromPayload(payload?.payment?.url)
    || optionalStringFromPayload(payload?.checkout_url)
    || optionalStringFromPayload(payload?.url);
}

function providerOrderId(payload) {
  return optionalStringFromPayload(payload?.response?.order?.invoice_number)
    || optionalStringFromPayload(payload?.order?.invoice_number)
    || optionalStringFromPayload(payload?.response?.order?.id)
    || optionalStringFromPayload(payload?.order?.id);
}

function notificationInvoiceNumber(payload) {
  return optionalStringFromPayload(payload?.order?.invoice_number)
    || optionalStringFromPayload(payload?.order?.invoiceNumber)
    || optionalStringFromPayload(payload?.invoice_number)
    || optionalStringFromPayload(payload?.invoiceNumber);
}

function notificationAmount(payload) {
  const value = payload?.order?.amount ?? payload?.order?.total_amount ?? payload?.amount ?? null;
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const amount = Number(value);
  return Number.isFinite(amount) ? amount : null;
}

function notificationEventType(payload) {
  return optionalStringFromPayload(payload?.transaction?.status)
    || optionalStringFromPayload(payload?.transaction?.type)
    || optionalStringFromPayload(payload?.payment?.type)
    || optionalStringFromPayload(payload?.event)
    || 'payment_notification';
}

function notificationOrderStatus(payload) {
  const rawStatus = optionalStringFromPayload(payload?.transaction?.status || payload?.status).toLowerCase();
  if (['success', 'capture', 'settlement', 'paid'].includes(rawStatus)) {
    return 'paid';
  }
  if (['failed', 'deny', 'failure'].includes(rawStatus)) {
    return 'failed';
  }
  if (['expired', 'expire'].includes(rawStatus)) {
    return 'expired';
  }
  if (['cancelled', 'canceled', 'cancel'].includes(rawStatus)) {
    return 'cancelled';
  }
  return 'pending';
}

function notificationPaidAt(payload) {
  const raw = optionalStringFromPayload(payload?.transaction?.date)
    || optionalStringFromPayload(payload?.transaction?.paid_at)
    || optionalStringFromPayload(payload?.paid_at);
  if (!raw) {
    return null;
  }
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function publicPaymentOrder(order) {
  return {
    invoiceNumber: order.invoiceNumber,
    provider: order.provider,
    plan: order.plan,
    amount: order.amount,
    currency: order.currency,
    status: order.status,
    checkoutUrl: order.checkoutUrl,
    paidAt: order.paidAt,
    expiresAt: order.expiresAt,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  };
}

function optionalStringFromPayload(value) {
  return typeof value === 'string' ? value.trim() : '';
}
