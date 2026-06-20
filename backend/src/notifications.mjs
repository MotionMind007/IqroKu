export function createNotificationRoutes({
  db,
  push,
  authenticateRequest,
  enforceChildOwnership,
  requiredBody,
  cleanString,
  truncateString,
  httpError,
}) {
  async function handle(method, path, url, body, request) {
    if (method === 'POST' && path === '/devices/register') {
      const authedParent = await authenticateRequest(request);
      const token = normalizeDeviceToken(requiredBody(body, 'token'));
      const platform = normalizeDevicePlatform(body.platform);
      const userType = cleanString(body.userType) || 'parent';
      const childId = cleanString(body.childId);

      if (!['parent', 'child'].includes(userType)) {
        throw httpError(400, 'invalid_user_type');
      }
      if (userType === 'child') {
        if (!childId) {
          throw httpError(400, 'missing_childId');
        }
        await enforceChildOwnership(authedParent.id, childId);
      }

      await db.upsertDeviceToken({
        parentId: authedParent.id,
        childId: userType === 'child' ? childId : null,
        userType,
        token,
        platform,
        appVersion: truncateString(cleanString(body.appVersion)).slice(0, 80),
        deviceModel: truncateString(cleanString(body.deviceModel)).slice(0, 200),
      });
      return { ok: true, pushConfigured: push.pushConfigured() };
    }

    if (method === 'POST' && path === '/devices/unregister') {
      const authedParent = await authenticateRequest(request);
      const token = normalizeDeviceToken(requiredBody(body, 'token'));
      await db.disableDeviceToken({ parentId: authedParent.id, token });
      return { ok: true };
    }

    if (method === 'GET' && path === '/notifications') {
      const authedParent = await authenticateRequest(request);
      const userType = url.searchParams.get('type') || 'parent';
      const childId = url.searchParams.get('childId');

      if (userType === 'child' && childId) {
        await enforceChildOwnership(authedParent.id, childId);
        return db.getNotifications(childId, 'child');
      }
      return db.getNotifications(authedParent.id, 'parent');
    }

    if (method === 'GET' && path === '/notifications/unread-count') {
      const authedParent = await authenticateRequest(request);
      const userType = url.searchParams.get('type') || 'parent';
      const childId = url.searchParams.get('childId');

      if (userType === 'child' && childId) {
        await enforceChildOwnership(authedParent.id, childId);
        return { count: await db.countUnreadNotifications(childId, 'child') };
      }
      return { count: await db.countUnreadNotifications(authedParent.id, 'parent') };
    }

    const notificationRead = notificationReadAction(path);
    if (method === 'POST' && notificationRead) {
      const authedParent = await authenticateRequest(request);
      const notification = await db.findNotificationById(notificationRead.id);
      if (!notification) {
        throw httpError(404, 'notification_not_found');
      }
      if (notification.user_type === 'child') {
        await enforceChildOwnership(authedParent.id, notification.user_id);
      } else if (notification.user_id !== authedParent.id) {
        throw httpError(403, 'access_denied');
      }
      await db.markNotificationRead(notification.id);
      return { ok: true };
    }

    if (method === 'POST' && path === '/notifications/read-all') {
      const authedParent = await authenticateRequest(request);
      const userType = cleanString(body.type) || 'parent';
      const childId = cleanString(body.childId);

      if (userType === 'child' && childId) {
        await enforceChildOwnership(authedParent.id, childId);
        await db.markAllNotificationsRead(childId, 'child');
      } else {
        await db.markAllNotificationsRead(authedParent.id, 'parent');
      }
      return { ok: true };
    }

    return null;
  }

  function normalizeDeviceToken(value) {
    const token = cleanString(value);
    if (token.length < 20 || token.length > 4096 || /[\s\x00-\x1F]/.test(token)) {
      throw httpError(400, 'invalid_device_token');
    }
    return token;
  }

  function normalizeDevicePlatform(value) {
    const platform = cleanString(value).toLowerCase() || 'unknown';
    return ['android', 'ios', 'web'].includes(platform) ? platform : 'unknown';
  }

  function notificationReadAction(path) {
    const match = /^\/notifications\/([^/]+)\/read$/.exec(path);
    if (!match) {
      return null;
    }
    return { id: decodeURIComponent(match[1]) };
  }

  return {
    handle,
  };
}
