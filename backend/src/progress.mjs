export function createProgressRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  requiredBody,
  requiredQuery,
  cleanString,
  clampNumber,
  httpError,
}) {
  async function handle(method, path, url, body, request) {
    if (method === 'GET' && path === '/progress') {
      const authedParent = await authenticateRequest(request);
      const childId = requiredQuery(url, 'childId');
      await enforceChildOwnership(authedParent.id, childId);
      return db.findProgressByChild(childId);
    }

    if (method === 'PUT' && path === '/progress') {
      const authedParent = await authenticateRequest(request);
      const childId = requiredBody(body, 'childId');
      await enforceChildOwnership(authedParent.id, childId);
      const bookId = clampNumber(Number(requiredBody(body, 'bookId')), 1, 99);
      const pageNumber = clampNumber(Number(requiredBody(body, 'pageNumber')), 1, 999);
      const status = cleanString(requiredBody(body, 'status'));
      const validStatuses = ['notStarted', 'learning', 'fluent', 'review'];
      if (!validStatuses.includes(status)) {
        throw httpError(400, 'invalid_status');
      }
      return db.upsertProgress({ childId, bookId, pageNumber, status });
    }

    if (method === 'POST' && path === '/assessments/mock') {
      throw httpError(410, 'assessment_disabled');
    }

    if (method === 'POST' && path === '/assessments/ai') {
      throw httpError(410, 'assessment_disabled');
    }

    return null;
  }

  return {
    handle,
  };
}
