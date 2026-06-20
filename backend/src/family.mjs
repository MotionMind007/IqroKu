export function createFamilyRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  requiredBody,
  requiredQuery,
  cleanString,
  truncateString,
  clampNumber,
  randomUUID,
  hashPassword,
  verifyPassword,
  httpError,
}) {
  async function handle(method, path, url, body, request) {
    if (method === 'GET' && path === '/children') {
      const authedParent = await authenticateRequest(request);
      const parentId = requiredQuery(url, 'parentId');
      if (parentId !== authedParent.id) {
        throw httpError(403, 'access_denied');
      }
      const children = await db.findChildrenByParent(parentId);
      return children.map(publicChild);
    }

    if (method === 'POST' && path === '/children') {
      const authedParent = await authenticateRequest(request);
      const parentId = requiredBody(body, 'parentId');
      if (parentId !== authedParent.id) {
        throw httpError(403, 'access_denied');
      }
      await enforceChildLimit(authedParent.id);
      const child = await db.createChild({
        id: randomUUID(),
        parentId,
        name: truncateString(cleanString(body.name) || 'Anak'),
        age: clampNumber(Number(body.age ?? 7), 1, 18),
        avatarAsset: cleanString(body.avatarAsset) || 'assets/brand/male-avatar.png',
      });
      return { status: 201, body: publicChild(child) };
    }

    if (method === 'POST' && path === '/auth/set-parent-pin') {
      const authedParent = await authenticateRequest(request);
      const pin = cleanString(body.pin);
      if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
        throw httpError(400, 'invalid_pin');
      }
      const pinHash = hashPassword(pin);
      await db.setParentPin(authedParent.id, pinHash);
      return { ok: true, message: 'PIN berhasil diset' };
    }

    if (method === 'POST' && path === '/auth/verify-parent-pin') {
      const authedParent = await authenticateRequest(request);
      const pin = cleanString(body.pin);
      if (!pin) {
        throw httpError(400, 'missing_pin');
      }
      const parent = await db.findParentById(authedParent.id);
      if (!parent?.pinHash) {
        throw httpError(400, 'pin_not_set');
      }
      const valid = verifyPassword(pin, parent.pinHash);
      return { valid };
    }

    if (method === 'POST' && path === '/auth/child-login') {
      const authedParent = await authenticateRequest(request);
      const childId = cleanString(body.childId);
      const pin = cleanString(body.pin);
      if (!childId || !pin) {
        throw httpError(400, 'missing_child_id_or_pin');
      }
      await enforceChildOwnership(authedParent.id, childId);
      const child = await db.findChildById(childId);
      if (!child?.pinHash) {
        throw httpError(400, 'child_pin_not_set');
      }
      const valid = verifyPassword(pin, child.pinHash);
      if (!valid) {
        throw httpError(401, 'invalid_pin');
      }
      return { valid: true, child: publicChild(child) };
    }

    const childPinAction = childSetPinAction(path);
    if (method === 'POST' && childPinAction) {
      const authedParent = await authenticateRequest(request);
      const childId = childPinAction.id;
      await enforceChildOwnership(authedParent.id, childId);
      const pin = cleanString(body.pin);
      if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
        throw httpError(400, 'invalid_pin');
      }
      const pinHash = hashPassword(pin);
      const child = await db.setChildPin(childId, pinHash);
      return { ok: true, child: publicChild(child) };
    }

    const childSchedule = childScheduleAction(path);
    if (method === 'POST' && childSchedule) {
      const authedParent = await authenticateRequest(request);
      const childId = childSchedule.id;
      await enforceChildOwnership(authedParent.id, childId);
      const startTime = cleanString(body.startTime);
      const endTime = cleanString(body.endTime);
      const days = Array.isArray(body.days) ? body.days : [1, 2, 3, 4, 5];
      const child = await db.updateChildSchedule(childId, startTime, endTime, days);
      return { ok: true, child: publicChild(child) };
    }

    return null;
  }

  async function enforceChildLimit(parentId) {
    const subscription = await db.findSubscriptionByParent(parentId);
    const limit = subscription?.active ? 5 : 1;
    const count = await db.countChildrenByParent(parentId);
    if (count >= limit) {
      throw httpError(402, 'child_limit_requires_plus');
    }
  }

  function publicChild(child) {
    if (!child) return child;
    const { pinHash, ...safeChild } = child;
    return {
      ...safeChild,
      hasPin: Boolean(pinHash),
    };
  }

  function childSetPinAction(path) {
    const match = /^\/children\/([^/]+)\/set-pin$/.exec(path);
    if (!match) {
      return null;
    }
    return { id: decodeURIComponent(match[1]) };
  }

  function childScheduleAction(path) {
    const match = /^\/children\/([^/]+)\/schedule$/.exec(path);
    if (!match) {
      return null;
    }
    return { id: decodeURIComponent(match[1]) };
  }

  return {
    handle,
  };
}
