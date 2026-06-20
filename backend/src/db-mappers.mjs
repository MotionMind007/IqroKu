export function rowToParent(row) {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    passwordHash: row.password_hash ?? undefined,
    googleId: row.google_id ?? undefined,
    pinHash: row.pin_hash ?? undefined,
    emailVerified: row.email_verified === true,
    emailVerifiedAt: row.email_verified_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
  };
}

export function rowToAuthToken(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    purpose: row.purpose,
    tokenHash: row.token_hash,
    expiresAt: row.expires_at?.toISOString(),
    usedAt: row.used_at?.toISOString(),
    metadata: row.metadata,
    createdAt: row.created_at?.toISOString(),
  };
}

export function rowToChild(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    name: row.name,
    age: row.age,
    avatarAsset: row.avatar_asset,
    pinHash: row.pin_hash ?? undefined,
    studyStartTime: row.study_start_time ?? undefined,
    studyEndTime: row.study_end_time ?? undefined,
    studyDays: row.study_days ?? [1, 2, 3, 4, 5],
    repeatFromPage: row.repeat_from_page ?? 1,
    repeatFromBook: row.repeat_from_book ?? 1,
    createdAt: row.created_at?.toISOString(),
  };
}

export function rowToProgress(row) {
  return {
    childId: row.child_id,
    bookId: row.book_id,
    pageNumber: row.page_number,
    status: row.status,
    updatedAt: row.updated_at?.toISOString(),
  };
}

export function rowToAttempt(row) {
  return {
    id: row.id,
    childId: row.child_id,
    bookId: row.book_id,
    pageNumber: row.page_number,
    durationSeconds: row.duration_seconds,
    audioPath: row.audio_path,
    audioUrl: row.audio_url,
    audioFileName: row.audio_file_name,
    audioContentType: row.audio_content_type,
    audioSizeBytes: row.audio_size_bytes,
    audioUploadedAt: row.audio_uploaded_at?.toISOString(),
    assessmentStatus: row.assessment_status,
    reviewStatus: row.review_status,
    reviewedAt: row.reviewed_at?.toISOString(),
    reviewedBy: row.reviewed_by ?? undefined,
    score: row.score,
    status: row.status,
    feedback: row.feedback,
    note: row.note,
    assessedAt: row.assessed_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
  };
}

export function rowToSubscription(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    plan: row.plan,
    priceId: row.price_id,
    active: row.active,
    activatedAt: row.activated_at?.toISOString(),
    activeUntil: row.active_until?.toISOString(),
  };
}

export function rowToPaymentOrder(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    provider: row.provider,
    invoiceNumber: row.invoice_number,
    requestId: row.request_id,
    plan: row.plan,
    amount: row.amount,
    currency: row.currency,
    status: row.status,
    checkoutUrl: row.checkout_url ?? undefined,
    providerOrderId: row.provider_order_id ?? undefined,
    rawResponse: row.raw_response ?? undefined,
    paidAt: row.paid_at?.toISOString(),
    expiresAt: row.expires_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
  };
}

export function rowToPaymentEvent(row) {
  return {
    id: row.id,
    provider: row.provider,
    requestId: row.request_id,
    invoiceNumber: row.invoice_number ?? undefined,
    eventType: row.event_type ?? undefined,
    signatureValid: row.signature_valid === true,
    payload: row.payload ?? {},
    receivedAt: row.received_at?.toISOString(),
  };
}

export function rowToPrayer(row) {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    arabic: row.arabic,
    latin: row.latin,
    meaning: row.meaning,
    sortOrder: row.sort_order,
    active: row.active,
    createdAt: row.created_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
  };
}

export function rowToDeviceToken(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    childId: row.child_id ?? undefined,
    userType: row.user_type,
    token: row.token,
    platform: row.platform,
    appVersion: row.app_version ?? undefined,
    deviceModel: row.device_model ?? undefined,
    enabled: row.enabled === true,
    lastSeenAt: row.last_seen_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
  };
}
