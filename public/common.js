// Tiện ích dùng chung cho mọi trang
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  del(k) { try { localStorage.removeItem(k); } catch {} },
};

const API = {
  async req(method, path, body) {
    const headers = { 'Content-Type': 'application/json' };
    const token = store.get('antam_token');
    if (token) headers.Authorization = 'Bearer ' + token;
    let res;
    try {
      res = await fetch('/api' + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
    } catch {
      throw new Error('Không kết nối được máy chủ. Kiểm tra mạng.');
    }
    const data = await res.json().catch(() => ({}));
    if (res.status === 401 && !path.startsWith('/auth/')) {
      store.del('antam_token');
      location.href = '/';
    }
    if (!res.ok) throw new Error(data.error || 'Có lỗi xảy ra');
    return data;
  },
  get(p) { return this.req('GET', p); },
  post(p, b) { return this.req('POST', p, b || {}); },
  put(p, b) { return this.req('PUT', p, b || {}); },
  del(p) { return this.req('DELETE', p); },
};

const HOME = { admin: '/admin.html', child: '/child.html', elder: '/elder.html' };

function goHome(role) { location.href = HOME[role] || '/'; }

async function requireRole(role) {
  if (!store.get('antam_token')) { location.href = '/'; throw new Error('no session'); }
  const me = await API.get('/me');
  if (me.role !== role) { goHome(me.role); throw new Error('wrong role'); }
  return me;
}

async function logout() {
  try { await API.post('/auth/logout'); } catch {}
  store.del('antam_token');
  location.href = '/';
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function toast(msg, kind = '') {
  let box = document.getElementById('toast');
  if (!box) { box = document.createElement('div'); box.id = 'toast'; document.body.appendChild(box); }
  box.textContent = msg;
  box.className = 'show ' + kind;
  clearTimeout(box._t);
  box._t = setTimeout(() => { box.className = ''; }, 3000);
}

function fmtDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString('vi-VN', { weekday: 'short', day: '2-digit', month: '2-digit' });
}

function fmtDateTime(iso) {
  const d = new Date(iso);
  return d.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' });
}

async function registerSW() {
  if (!('serviceWorker' in navigator)) return null;
  try { return await navigator.serviceWorker.register('/sw.js'); } catch { return null; }
}

// Hiện thông báo hệ thống (Android cần đi qua service worker)
async function showSystemNotification(title, options) {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  try {
    const reg = await navigator.serviceWorker?.getRegistration();
    if (reg) return reg.showNotification(title, options);
    new Notification(title, options);
  } catch {}
}
