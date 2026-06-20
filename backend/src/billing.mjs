export function createBillingRoutes({
  db,
  dokuPayments,
  authenticateRequest,
  authenticateAdmin,
  requiredBody,
  randomUUID,
  now,
  addDays,
  httpError,
}) {
  async function handle(method, path, body, request) {
    if (method === 'POST' && path === '/subscriptions/activate') {
      authenticateAdmin(request);
      const parentId = requiredBody(body, 'parentId');
      const parent = await db.findParentById(parentId);
      if (!parent) {
        throw httpError(404, 'parent_not_found');
      }
      const activeUntil = addDays(new Date(), 30).toISOString();
      return db.upsertSubscription({
        id: randomUUID(),
        parentId,
        plan: 'plus',
        priceId: 'iqroku_plus_49000_monthly',
        active: true,
        activatedAt: now(),
        activeUntil,
      });
    }

    if (method === 'GET' && path === '/subscriptions/status') {
      const authedParent = await authenticateRequest(request);
      const subscription = await db.findSubscriptionByParent(authedParent.id);
      return {
        subscription: publicSubscription(subscription),
      };
    }

    if (method === 'POST' && path === '/payments/doku/checkout') {
      const authedParent = await authenticateRequest(request);
      return dokuPayments.createCheckout(authedParent);
    }

    const paymentStatus = paymentStatusAction(path);
    if (method === 'GET' && paymentStatus) {
      const authedParent = await authenticateRequest(request);
      const order = await db.findPaymentOrderByInvoiceNumber(paymentStatus.invoiceNumber);
      if (!order) {
        throw httpError(404, 'payment_order_not_found');
      }
      if (order.parentId !== authedParent.id) {
        throw httpError(403, 'access_denied');
      }
      return dokuPayments.publicPaymentOrder(order);
    }

    return null;
  }

  function publicSubscription(subscription) {
    if (!subscription) {
      return {
        active: false,
        plan: 'free',
        activeUntil: null,
        activatedAt: null,
      };
    }
    const activeUntil = subscription.activeUntil ? new Date(subscription.activeUntil) : null;
    const active = subscription.active === true
      && (!activeUntil || activeUntil.getTime() > Date.now());
    return {
      active,
      plan: active ? subscription.plan : 'free',
      activeUntil: subscription.activeUntil ?? null,
      activatedAt: subscription.activatedAt ?? null,
    };
  }

  function paymentStatusAction(path) {
    const match = /^\/payments\/status\/([^/]+)$/.exec(path);
    if (!match) {
      return null;
    }
    return { invoiceNumber: decodeURIComponent(match[1]) };
  }

  return {
    handle,
  };
}
