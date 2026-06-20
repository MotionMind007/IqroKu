export function createAdminPanel({
  db,
  adminToken,
  secureCookieAttribute,
  safeStrEqual,
  createCsrfToken,
  verifyCsrfToken,
  enforceCsrf,
  cleanString,
  requiredBody,
  normalizeEmail,
  parseBoolean,
  randomUUID,
  httpError,
  escapeHtml,
  formatDateTime,
  rupiah,
}) {
  async function handle(method, path, body, request) {
    if (method === 'GET' && path === '/admin/login') {
      return { html: renderAdminLogin() };
    }

    if (method === 'POST' && path === '/admin/login') {
      if (!verifyCsrfToken(body.csrfToken)) {
        return { html: renderAdminLogin('Form kedaluwarsa. Muat ulang halaman lalu coba lagi.') };
      }
      const token = cleanString(body.token);
      if (!safeStrEqual(token, adminToken)) {
        return { html: renderAdminLogin('Token salah. Silakan coba lagi.') };
      }
      return {
        status: 302,
        headers: {
          'Set-Cookie': `admin_token=${token}; Path=/admin; HttpOnly; SameSite=Strict; Max-Age=86400${secureCookieAttribute()}`,
          'Location': '/admin',
        },
        body: '',
      };
    }

    if (method === 'GET' && path === '/admin/logout') {
      return {
        status: 302,
        headers: {
          'Set-Cookie': `admin_token=; Path=/admin; HttpOnly; SameSite=Strict; Max-Age=0${secureCookieAttribute()}`,
          'Location': '/admin/login',
        },
        body: '',
      };
    }

    if (method === 'GET' && path === '/admin') {
      authenticateAdmin(request);
      const metrics = await db.getAdminMetrics();
      return { html: renderAdminDashboard(metrics) };
    }

    if (method === 'GET' && path === '/admin/metrics') {
      authenticateAdmin(request);
      return db.getAdminMetrics();
    }

    if (method === 'GET' && path === '/admin/prayers') {
      authenticateAdmin(request);
      const prayers = await db.getAllPrayers();
      return { html: renderAdminPrayers(prayers) };
    }

    if (method === 'POST' && path === '/admin/prayers') {
      authenticateAdmin(request);
      enforceCsrf(body);
      const fields = prayerFromBody(body);
      await db.createPrayer({
        id: randomUUID(),
        ...fields,
        active: parseBoolean(body.active, true),
      });
      const prayers = await db.getAllPrayers();
      return { html: renderAdminPrayers(prayers, 'Doa baru sudah tersimpan.') };
    }

    const prayerAction = adminPrayerAction(path);
    if (method === 'POST' && prayerAction) {
      authenticateAdmin(request);
      enforceCsrf(body);
      const prayer = await db.findPrayerById(prayerAction.id);
      if (!prayer) {
        throw httpError(404, 'prayer_not_found');
      }
      if (prayerAction.action === 'delete') {
        await db.deletePrayer(prayerAction.id);
        const prayers = await db.getAllPrayers();
        return { html: renderAdminPrayers(prayers, 'Doa sudah dihapus.') };
      }
      await db.updatePrayer(prayerAction.id, {
        ...prayerFromBody(body),
        active: parseBoolean(body.active, false),
      });
      const prayers = await db.getAllPrayers();
      return { html: renderAdminPrayers(prayers, 'Perubahan doa sudah tersimpan.') };
    }

    const parentAction = adminParentAction(path);
    if (method === 'POST' && parentAction?.action === 'delete') {
      authenticateAdmin(request);
      enforceCsrf(body);
      const parent = await db.findParentById(parentAction.id);
      if (!parent) {
        throw httpError(404, 'parent_not_found');
      }
      const confirmEmail = normalizeEmail(requiredBody(body, 'confirmEmail'));
      if (confirmEmail !== parent.email) {
        const metrics = await db.getAdminMetrics();
        return {
          html: renderAdminDashboard(metrics, `Konfirmasi email tidak cocok untuk ${parent.email}.`),
        };
      }
      await db.deleteParent(parent.id);
      const metrics = await db.getAdminMetrics();
      return { html: renderAdminDashboard(metrics, `User ${parent.email} sudah dihapus.`) };
    }

    return null;
  }

  function authenticateAdmin(request) {
    const authHeader = request.headers?.['authorization'] ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7).trim()
      : '';
    const cookie = request.headers?.['cookie'] ?? '';
    const cookieToken = cookie.match(/admin_token=([^;]+)/)?.[1] ?? '';

    if (!safeStrEqual(token, adminToken) && !safeStrEqual(cookieToken, adminToken)) {
      throw httpError(403, 'admin_access_denied');
    }
  }

  return { handle };

  function createAdminCsrfToken() {
    return createCsrfToken();
  }

function prayerFromBody(body) {
  const title = cleanString(requiredBody(body, 'title'));
  const arabic = cleanString(requiredBody(body, 'arabic'));
  const meaning = cleanString(requiredBody(body, 'meaning'));
  return {
    title,
    category: cleanString(body.category) || 'Harian',
    arabic,
    latin: cleanString(body.latin),
    meaning,
    sortOrder: Number(body.sortOrder ?? 100),
  };
}

function adminPrayerAction(path) {
  const match = /^\/admin\/prayers\/([^/]+)\/(update|delete)$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]), action: match[2] };
}

function adminParentAction(path) {
  const match = /^\/admin\/parents\/([^/]+)\/(delete)$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]), action: match[2] };
}


function renderAdminLogin(error = '', csrfToken = createAdminCsrfToken()) {
  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login - IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --danger: #d84f3f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .login-card {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 20px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, .08);
        padding: 40px;
        width: min(420px, calc(100% - 32px));
      }
      h1 { margin: 0 0 8px; font-size: 24px; }
      p { margin: 0 0 24px; color: var(--muted); font-size: 14px; }
      label {
        display: grid;
        gap: 8px;
        color: var(--muted);
        font-size: 13px;
        font-weight: 700;
        margin-bottom: 20px;
      }
      input {
        width: 100%;
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 14px 16px;
        color: var(--text);
        background: #fff;
        font: inherit;
        font-size: 15px;
      }
      input:focus {
        outline: none;
        border-color: var(--primary);
        box-shadow: 0 0 0 3px rgba(35, 134, 75, .15);
      }
      button {
        width: 100%;
        border: 0;
        border-radius: 12px;
        padding: 14px;
        background: var(--primary);
        color: #fff;
        font-weight: 800;
        font-size: 15px;
        cursor: pointer;
        transition: background .2s;
      }
      button:hover { background: var(--primary-dark); }
      .error {
        padding: 12px 16px;
        margin-bottom: 20px;
        border: 1px solid rgba(216, 79, 63, .3);
        border-radius: 12px;
        background: #fff0ee;
        color: var(--danger);
        font-size: 14px;
        font-weight: 600;
      }
      .footer {
        margin-top: 20px;
        text-align: center;
        color: var(--muted);
        font-size: 12px;
      }
    </style>
  </head>
  <body>
    <div class="login-card">
      <h1>IqroKu Admin</h1>
      <p>Masukkan admin token untuk mengakses dashboard.</p>
      ${error ? `<div class="error">${escapeHtml(error)}</div>` : ''}
      <form method="post" action="/admin/login">
        <input name="csrfToken" type="hidden" value="${escapeHtml(csrfToken)}">
        <label>
          Admin Token
          <input name="token" type="password" placeholder="Masukkan token..." required autofocus>
        </label>
        <button type="submit">Masuk</button>
      </form>
      <div class="footer">
        IqroKu &copy; ${new Date().getFullYear()}
      </div>
    </div>
  </body>
</html>`;
}

function renderAdminDashboard(metrics, notice = '', csrfToken = createAdminCsrfToken()) {
  const cards = [
    ['Total Parent', metrics.totals.parents],
    ['Profil Anak', metrics.totals.children],
    ['Free Users', metrics.totals.freeParents],
    ['Plus Users', metrics.totals.plusParents],
    ['Subscription Aktif', metrics.totals.activeSubscriptions],
    ['MRR Estimasi', rupiah(metrics.totals.monthlyRevenue)],
    ['Parent Aktif Hari Ini', metrics.totals.activeParentsToday],
  ];

  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --paper: #fffbf1;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --gold: #e2a83b;
        --coral: #e66c55;
        --blue: #4f8cc9;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
      }
      main {
        width: min(1180px, calc(100% - 32px));
        margin: 0 auto;
        padding: 28px 0 44px;
      }
      header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 16px;
        margin-bottom: 22px;
      }
      h1, h2 { margin: 0; letter-spacing: 0; }
      h1 { font-size: 28px; }
      h2 { font-size: 18px; margin-bottom: 12px; }
      p { margin: 6px 0 0; color: var(--muted); }
      a {
        color: var(--primary);
        font-weight: 800;
        text-decoration: none;
      }
      .badge {
        display: inline-flex;
        align-items: center;
        border: 1px solid rgba(35, 134, 75, .22);
        border-radius: 999px;
        padding: 8px 12px;
        color: var(--primary-dark);
        background: #e7f5ec;
        font-size: 13px;
        font-weight: 800;
        white-space: nowrap;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 12px;
      }
      .card, section {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 16px;
        box-shadow: 0 6px 14px rgba(0, 0, 0, .06);
      }
      .card { padding: 16px; }
      .card span {
        display: block;
        color: var(--muted);
        font-size: 12px;
        font-weight: 700;
      }
      .card strong {
        display: block;
        margin-top: 7px;
        font-size: 24px;
      }
      section {
        margin-top: 18px;
        overflow: hidden;
      }
      .section-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 12px;
        padding: 16px;
        background: var(--paper);
        border-bottom: 1px solid var(--line);
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        padding: 12px 16px;
        border-bottom: 1px solid var(--line);
        text-align: left;
        font-size: 13px;
        vertical-align: top;
      }
      th {
        color: var(--muted);
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: .04em;
      }
      tr:last-child td { border-bottom: 0; }
      .pill {
        display: inline-flex;
        padding: 5px 9px;
        border-radius: 999px;
        background: rgba(35, 134, 75, .12);
        color: var(--primary);
        font-size: 12px;
        font-weight: 800;
      }
      .pill.free { background: rgba(141, 148, 143, .14); color: var(--muted); }
      .pill.pending { background: rgba(226, 168, 59, .16); color: #8b6412; }
      .pill.review { background: rgba(230, 108, 85, .14); color: var(--coral); }
      .muted { color: var(--muted); }
      .empty {
        padding: 18px 16px;
        color: var(--muted);
      }
      .notice {
        margin: 0 0 16px;
        padding: 12px 14px;
        border: 1px solid rgba(35, 134, 75, .22);
        border-radius: 12px;
        background: #e7f5ec;
        color: var(--primary-dark);
        font-weight: 800;
      }
      .danger-form {
        display: grid;
        gap: 8px;
        min-width: 220px;
      }
      .danger-form input {
        width: 100%;
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 8px 10px;
        font: inherit;
      }
      .danger-form button {
        border: 0;
        border-radius: 8px;
        padding: 8px 10px;
        background: var(--coral);
        color: #fff;
        font-weight: 800;
        cursor: pointer;
      }
      @media (max-width: 920px) {
        .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        header { flex-direction: column; }
        table { display: block; overflow-x: auto; }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <div>
          <h1>IqroKu Admin</h1>
          <p>Prototype dashboard untuk user, subscription, revenue, rekaman, dan review.</p>
        </div>
        <div>
          <span class="badge">Generated ${escapeHtml(formatDateTime(metrics.generatedAt))}</span>
          <p><a href="/admin/prayers">Kelola Doa</a> · <a href="/admin/metrics">View JSON metrics</a> · <a href="/admin/logout">Logout</a></p>
        </div>
      </header>

      ${notice ? `<div class="notice">${escapeHtml(notice)}</div>` : ''}

      <div class="grid">
        ${cards.map(([label, value]) => `
          <div class="card">
            <span>${escapeHtml(label)}</span>
            <strong>${escapeHtml(String(value))}</strong>
          </div>
        `).join('')}
      </div>

      ${renderParentsTable(metrics.parents, metrics.limits?.parents, csrfToken)}
      ${renderSubscriptionsTable(metrics.subscriptions, metrics.limits?.subscriptions)}
    </main>
  </body>
</html>`;
}

function renderAdminPrayers(prayers, notice = '', csrfToken = createAdminCsrfToken()) {
  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Kelola Doa - IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --paper: #fffbf1;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --danger: #d84f3f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
      }
      main {
        width: min(980px, calc(100% - 32px));
        margin: 0 auto;
        padding: 28px 0 44px;
      }
      header {
        display: flex;
        justify-content: space-between;
        gap: 16px;
        align-items: flex-start;
        margin-bottom: 18px;
      }
      h1, h2, h3 { margin: 0; letter-spacing: 0; }
      h1 { font-size: 28px; }
      h2 { font-size: 18px; }
      h3 { font-size: 16px; }
      p { margin: 6px 0 0; color: var(--muted); }
      a {
        color: var(--primary);
        font-weight: 800;
        text-decoration: none;
      }
      section, .prayer {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 16px;
        box-shadow: 0 6px 14px rgba(0, 0, 0, .06);
      }
      section { padding: 16px; margin-bottom: 16px; }
      .notice {
        padding: 12px 14px;
        margin-bottom: 16px;
        border: 1px solid rgba(35, 134, 75, .2);
        border-radius: 12px;
        background: #e7f5ec;
        color: var(--primary-dark);
        font-weight: 800;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
      }
      label {
        display: grid;
        gap: 7px;
        color: var(--muted);
        font-size: 12px;
        font-weight: 800;
      }
      input, textarea {
        width: 100%;
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 11px 12px;
        color: var(--text);
        background: #fff;
        font: inherit;
      }
      textarea { min-height: 96px; resize: vertical; }
      .wide { grid-column: 1 / -1; }
      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        align-items: center;
        margin-top: 12px;
      }
      button {
        border: 0;
        border-radius: 999px;
        padding: 10px 15px;
        background: var(--primary);
        color: #fff;
        font-weight: 900;
        cursor: pointer;
      }
      button.secondary {
        background: #edf6f0;
        color: var(--primary-dark);
      }
      button.danger {
        background: #fff0ee;
        color: var(--danger);
      }
      .check {
        display: inline-flex;
        grid-auto-flow: column;
        align-items: center;
        gap: 8px;
        color: var(--text);
      }
      .check input { width: auto; }
      .prayer {
        padding: 16px;
        margin-bottom: 12px;
      }
      .prayer-head {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        margin-bottom: 12px;
      }
      .pill {
        display: inline-flex;
        align-items: center;
        height: 28px;
        padding: 0 10px;
        border-radius: 999px;
        background: rgba(35, 134, 75, .12);
        color: var(--primary);
        font-size: 12px;
        font-weight: 900;
        white-space: nowrap;
      }
      .pill.off {
        background: rgba(109, 117, 111, .14);
        color: var(--muted);
      }
      .empty {
        padding: 18px 0;
        color: var(--muted);
      }
      @media (max-width: 720px) {
        header { flex-direction: column; }
        .grid { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <div>
          <h1>Kelola Doa</h1>
          <p>Update konten Doa-doa dari dashboard, lalu aplikasi akan mengambil data terbaru dari backend.</p>
        </div>
        <p><a href="/admin">Dashboard</a> · <a href="/daily-prayers">JSON publik</a></p>
      </header>

      ${notice ? `<div class="notice">${escapeHtml(notice)}</div>` : ''}

      <section>
        <h2>Tambah Doa Baru</h2>
        <p>Isi minimal judul, Arab, dan arti. Urutan kecil tampil lebih atas.</p>
        <form method="post" action="/admin/prayers">
          <input name="csrfToken" type="hidden" value="${escapeHtml(csrfToken)}">
          ${renderPrayerFields({
            title: '',
            category: 'Harian',
            arabic: '',
            latin: '',
            meaning: '',
            sortOrder: nextPrayerSortOrder(prayers),
            active: true,
          })}
          <div class="actions">
            <button type="submit">Simpan Doa</button>
          </div>
        </form>
      </section>

      <section>
        <h2>Daftar Doa</h2>
        <p>${prayers.length} konten doa tersimpan.</p>
      </section>

      ${prayers.length ? prayers.map((prayer) => renderPrayerEditor(prayer, csrfToken)).join('') : '<div class="empty">Belum ada doa.</div>'}
    </main>
  </body>
</html>`;
}

function renderPrayerEditor(prayer, csrfToken) {
  return `<div class="prayer">
    <div class="prayer-head">
      <div>
        <h3>${escapeHtml(prayer.title)}</h3>
        <p>${escapeHtml(prayer.category || 'Harian')} · Urutan ${escapeHtml(prayer.sortOrder ?? 0)}</p>
      </div>
      <span class="pill ${prayer.active === false ? 'off' : ''}">${prayer.active === false ? 'Nonaktif' : 'Aktif'}</span>
    </div>
    <form method="post" action="/admin/prayers/${encodeURIComponent(prayer.id)}/update">
      <input name="csrfToken" type="hidden" value="${escapeHtml(csrfToken)}">
      ${renderPrayerFields(prayer)}
      <div class="actions">
        <button type="submit">Update</button>
      </div>
    </form>
    <form method="post" action="/admin/prayers/${encodeURIComponent(prayer.id)}/delete">
      <input name="csrfToken" type="hidden" value="${escapeHtml(csrfToken)}">
      <div class="actions">
        <button class="danger" type="submit">Hapus</button>
      </div>
    </form>
  </div>`;
}

function renderPrayerFields(prayer) {
  return `<div class="grid">
    <label>
      Judul
      <input name="title" required value="${escapeHtml(prayer.title)}">
    </label>
    <label>
      Kategori
      <input name="category" value="${escapeHtml(prayer.category)}">
    </label>
    <label class="wide">
      Teks Arab
      <textarea name="arabic" required dir="rtl">${escapeHtml(prayer.arabic)}</textarea>
    </label>
    <label class="wide">
      Latin
      <textarea name="latin">${escapeHtml(prayer.latin)}</textarea>
    </label>
    <label class="wide">
      Arti Indonesia
      <textarea name="meaning" required>${escapeHtml(prayer.meaning)}</textarea>
    </label>
    <label>
      Urutan
      <input name="sortOrder" type="number" value="${escapeHtml(prayer.sortOrder ?? 100)}">
    </label>
    <label class="check">
      <input name="active" type="checkbox" ${prayer.active === false ? '' : 'checked'}>
      Aktif tampil di app
    </label>
  </div>`;
}

function nextPrayerSortOrder(prayers) {
  const maxSort = prayers.reduce((max, prayer) => {
    return Math.max(max, Number(prayer.sortOrder ?? 0));
  }, 0);
  return maxSort + 10;
}

function renderParentsTable(parents, limit, csrfToken) {
  return `<section>
    <div class="section-head">
      <h2>Users Parent</h2>
      <span class="muted">${parents.length}${limit ? `/${limit}` : ''} terbaru</span>
    </div>
    ${parents.length ? `<table>
      <thead>
        <tr>
          <th>Nama</th>
          <th>Email</th>
          <th>Plan</th>
          <th>Anak</th>
          <th>Created</th>
          <th>Aksi</th>
        </tr>
      </thead>
      <tbody>
        ${parents.map((parent) => `
          <tr>
            <td>${escapeHtml(parent.name)}</td>
            <td>${escapeHtml(parent.email)}</td>
            <td><span class="pill ${parent.plan === 'Free' ? 'free' : ''}">${escapeHtml(parent.plan)}</span></td>
            <td>${parent.childrenCount}</td>
            <td>${escapeHtml(formatDateTime(parent.createdAt))}</td>
            <td>
              <form class="danger-form" method="post" action="/admin/parents/${encodeURIComponent(parent.id)}/delete">
                <input name="csrfToken" type="hidden" value="${escapeHtml(csrfToken)}">
                <input name="confirmEmail" type="email" placeholder="Ketik email untuk hapus" autocomplete="off" required>
                <button type="submit">Delete user</button>
              </form>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada user parent.</div>'}
  </section>`;
}

function renderSubscriptionsTable(subscriptions, limit) {
  return `<section>
    <div class="section-head">
      <h2>Subscriptions</h2>
      <span class="muted">${subscriptions.length}${limit ? `/${limit}` : ''} terbaru</span>
    </div>
    ${subscriptions.length ? `<table>
      <thead>
        <tr>
          <th>Parent</th>
          <th>Plan</th>
          <th>Status</th>
          <th>Aktif</th>
          <th>Sampai</th>
        </tr>
      </thead>
      <tbody>
        ${subscriptions.map((subscription) => `
          <tr>
            <td>${escapeHtml(subscription.parentEmail || subscription.parentId)}</td>
            <td>${escapeHtml(subscription.plan ?? '-')}</td>
            <td><span class="pill ${subscription.active ? '' : 'free'}">${subscription.active ? 'Aktif' : 'Tidak aktif'}</span></td>
            <td>${escapeHtml(formatDateTime(subscription.activatedAt))}</td>
            <td>${escapeHtml(formatDateTime(subscription.activeUntil))}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada subscription.</div>'}
  </section>`;
}


}
