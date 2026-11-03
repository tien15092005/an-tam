// Trang đăng nhập
(async () => {
  if (store.get('antam_token')) {
    try { const me = await API.get('/me'); return goHome(me.role); } catch { store.del('antam_token'); }
  }
})();

function show(id) {
  for (const s of ['choose', 'child-auth', 'elder-auth']) document.getElementById(s).hidden = s !== id;
  if (id === 'elder-auth') document.querySelector('.code-input').focus();
}
document.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', () => show(b.dataset.go)));

document.querySelectorAll('[data-tab]').forEach(b => b.addEventListener('click', () => {
  document.querySelectorAll('[data-tab]').forEach(x => x.classList.toggle('active', x === b));
  document.getElementById('login-form').hidden = b.dataset.tab !== 'login';
  document.getElementById('register-form').hidden = b.dataset.tab !== 'register';
}));

function bind(formId, path) {
  const form = document.getElementById(formId);
  form.addEventListener('submit', async e => {
    e.preventDefault();
    const err = form.querySelector('.error');
    const btn = form.querySelector('button.primary');
    err.textContent = '';
    btn.disabled = true;
    try {
      const res = await API.post(path, Object.fromEntries(new FormData(form)));
      store.set('antam_token', res.token);
      goHome(res.user.role);
    } catch (ex) {
      err.textContent = ex.message;
    } finally {
      btn.disabled = false;
    }
  });
}
bind('login-form', '/auth/login');
bind('register-form', '/auth/register');
bind('elder-form', '/auth/elder-login');
