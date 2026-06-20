import { mkdir, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';

export function createLearningRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  queuePushNotification,
  logError,
  requiredBody,
  requiredQuery,
  cleanString,
  clampNumber,
  randomUUID,
  now,
  httpError,
  uploadDir,
  maxAudioUploadBytes,
  allowedAudioContentTypes,
  genericAudioUploadContentTypes,
  allowedAudioExtensions,
}) {
  async function handle(method, path, url, body, request) {
    if (method === 'GET' && path.startsWith('/uploads/audio/')) {
      const authedParent = await authenticateRequest(request);
      const fileName = safeStoredFileName(path.split('/').pop() ?? '');
      const attempt = await db.findAttemptByAudioFileName(fileName);
      if (!attempt) {
        throw httpError(404, 'file_not_found');
      }
      await enforceChildOwnership(authedParent.id, attempt.childId);
      return {
        filePath: resolve(uploadDir, fileName),
        contentType: contentTypeForAudio(fileName),
      };
    }

    if (method === 'GET' && path === '/attempts') {
      const authedParent = await authenticateRequest(request);
      const childId = requiredQuery(url, 'childId');
      await enforceChildOwnership(authedParent.id, childId);
      return db.findAttemptsByChild(childId);
    }

    if (method === 'POST' && path === '/attempts') {
      const authedParent = await authenticateRequest(request);
      const childId = requiredBody(body, 'childId');
      await enforceChildOwnership(authedParent.id, childId);
      const attemptId = cleanString(body.id) || randomUUID();
      const bookId = clampNumber(Number(requiredBody(body, 'bookId')), 1, 99);
      const pageNumber = clampNumber(Number(requiredBody(body, 'pageNumber')), 1, 999);

      const attempt = await db.createAttempt({
        id: attemptId,
        childId,
        bookId,
        pageNumber,
        durationSeconds: clampNumber(Number(body.durationSeconds ?? 1), 1, 3600),
        audioPath: cleanString(body.audioPath) || null,
      });

      try {
        const child = await db.findChildById(childId);
        if (child) {
          const notification = await db.createNotification({
            userId: child.parentId,
            userType: 'parent',
            type: 'new_recording',
            title: `${child.name} sudah merekam`,
            message: `${child.name} telah membaca Iqro ${bookId} halaman ${pageNumber}`,
            data: { childId, bookId, pageNumber, attemptId },
          });
          queuePushNotification(notification);
        }
      } catch (err) {
        logError('notification_create_failed', err, { childId, bookId, pageNumber, attemptId });
      }

      return { status: 201, body: attempt };
    }

    const audioUpload = attemptAudioUpload(path);
    if (method === 'POST' && audioUpload) {
      const authedParent = await authenticateRequest(request);
      const attempt = await db.findAttemptById(audioUpload.attemptId);
      if (!attempt) {
        throw httpError(404, 'attempt_not_found');
      }
      await enforceChildOwnership(authedParent.id, attempt.childId);
      const audio = body.__multipart?.files?.audio;
      if (!audio?.content?.length) {
        throw httpError(400, 'missing_audio');
      }
      const stored = await storeAttemptAudio({
        attemptId: attempt.id,
        originalFileName: audio.fileName,
        contentType: audio.contentType,
        content: audio.content,
      });
      return db.updateAttempt(attempt.id, {
        audioPath: stored.url,
        audioUrl: stored.url,
        audioFileName: stored.fileName,
        audioContentType: stored.contentType,
        audioSizeBytes: stored.sizeBytes,
        audioUploadedAt: now(),
      });
    }

    if (method === 'GET' && path === '/reviews/pending') {
      const authedParent = await authenticateRequest(request);
      return db.getPendingReviews(authedParent.id);
    }

    if (method === 'POST' && path === '/reviews/approve') {
      const authedParent = await authenticateRequest(request);
      const attemptId = requiredBody(body, 'attemptId');
      const attempt = await db.findAttemptById(attemptId);
      if (!attempt) {
        throw httpError(404, 'attempt_not_found');
      }
      await enforceChildOwnership(authedParent.id, attempt.childId);

      const notification = await db.approveReview({
        attempt,
        reviewedBy: authedParent.id,
      });
      queuePushNotification(notification);
      return { ok: true, status: 'approved' };
    }

    if (method === 'POST' && path === '/reviews/repeat') {
      const authedParent = await authenticateRequest(request);
      const attemptId = requiredBody(body, 'attemptId');
      const fromPage = Number(body.fromPage);
      if (!Number.isInteger(fromPage) || fromPage < 1) {
        throw httpError(400, 'invalid_repeat_page');
      }
      const attempt = await db.findAttemptById(attemptId);
      if (!attempt) {
        throw httpError(404, 'attempt_not_found');
      }
      await enforceChildOwnership(authedParent.id, attempt.childId);
      if (fromPage > attempt.pageNumber) {
        throw httpError(400, 'invalid_repeat_page');
      }

      const notification = await db.repeatReview({
        attempt,
        reviewedBy: authedParent.id,
        fromPage,
      });
      queuePushNotification(notification);
      return { ok: true, status: 'needs_repeat', fromPage };
    }

    return null;
  }

  async function storeAttemptAudio({ attemptId, originalFileName, contentType, content }) {
    validateAudioUpload({ originalFileName, contentType, content });
    await mkdir(uploadDir, { recursive: true });
    const extension = audioExtension(originalFileName, contentType);
    const fileName = safeStoredFileName(`${attemptId}-${Date.now()}${extension}`);
    await writeFile(resolve(uploadDir, fileName), content);
    const normalizedType = contentType.split(';')[0].trim().toLowerCase();
    return {
      fileName,
      contentType: genericAudioUploadContentTypes.has(normalizedType)
        ? contentTypeForAudio(fileName)
        : contentType,
      sizeBytes: content.length,
      url: `/uploads/audio/${fileName}`,
    };
  }

  function validateAudioUpload({ originalFileName = '', contentType = '', content }) {
    if (!Buffer.isBuffer(content) || content.length === 0) {
      throw httpError(400, 'audio_file_empty');
    }
    if (content.length > maxAudioUploadBytes) {
      throw httpError(413, 'audio_file_too_large');
    }

    const normalizedType = contentType.split(';')[0].trim().toLowerCase();
    const genericBinaryUpload = genericAudioUploadContentTypes.has(normalizedType);
    if (!genericBinaryUpload && !allowedAudioContentTypes.has(normalizedType)) {
      throw httpError(415, 'unsupported_audio_type');
    }

    const extension = extname(originalFileName).toLowerCase();
    if (!extension || !allowedAudioExtensions.has(extension)) {
      throw httpError(415, 'unsupported_audio_extension');
    }

    if (!looksLikeAudio(content)) {
      throw httpError(415, 'invalid_audio_file');
    }
  }

  function looksLikeAudio(content) {
    if (content.length < 12) {
      return false;
    }
    const ascii = content.subarray(0, 16).toString('latin1');
    if (ascii.startsWith('RIFF') && ascii.includes('WAVE')) return true;
    if (ascii.startsWith('ID3')) return true;
    if (content[0] === 0xff && (content[1] & 0xe0) === 0xe0) return true;
    if (ascii.includes('ftyp')) return true;
    if (ascii.startsWith('\x1aE\xdf\xa3')) return true;
    return false;
  }

  function audioExtension(fileName = '', contentType = '') {
    const extension = extname(fileName).toLowerCase();
    if (allowedAudioExtensions.has(extension)) {
      return extension;
    }
    const normalizedType = contentType.split(';')[0].trim().toLowerCase();
    if (normalizedType.includes('mpeg')) {
      return '.mp3';
    }
    if (normalizedType.includes('wav')) {
      return '.wav';
    }
    if (normalizedType.includes('webm')) {
      return '.webm';
    }
    if (normalizedType.includes('3gpp')) {
      return '.aac';
    }
    return '.m4a';
  }

  function safeStoredFileName(fileName) {
    return String(fileName).replaceAll(/[^a-zA-Z0-9._-]/g, '_');
  }

  function contentTypeForAudio(fileName) {
    const extension = extname(fileName).toLowerCase();
    return {
      '.aac': 'audio/aac',
      '.m4a': 'audio/mp4',
      '.mp3': 'audio/mpeg',
      '.mp4': 'audio/mp4',
      '.wav': 'audio/wav',
      '.webm': 'audio/webm',
    }[extension] ?? 'application/octet-stream';
  }

  function attemptAudioUpload(path) {
    const match = /^\/attempts\/([^/]+)\/audio$/.exec(path);
    if (!match) {
      return null;
    }
    return { attemptId: decodeURIComponent(match[1]) };
  }

  return {
    handle,
  };
}
