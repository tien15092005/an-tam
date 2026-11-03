// Trang quản trị: thống kê + quản lý tài khoản
const $ = s => document.querySelector(s);
const ROLE = { admin: 'Admin', child: 'Người con', elder: 'Bố mẹ' };
let me, users = [];

async function load() {
  const [stats, list] = await Promise.all([API.get('/admin/stats'), API.get('/admin/users')]);
  users = list;
  $('#stats').innerHTML = [
    ['Người con', stats.children], ['Bố mẹ', stats.elders], ['Thuốc đang theo dõi', stats.medications],
    ['Lượt uống hôm nay', stats.taken_today], ['Cảnh báo chưa xử lý', stats.open_alerts, stats.open_alerts ? 'bad' : ''],
    ['Tài khoản bị khóa', stats.locked],
  ].map(([k, v, cls = '']) => `<div class="stat ${cls}"><div class="k">${k}</div><div class="v">${v}</div></div>`).join('');
  render();
}

function render() {
  const role = $('#role-filter').value;
  const q = $('#search').value.trim().toLowerCase();
  const rows = users.filter(u => (!role || u.role === role)
    && (!q || [u.name, u.email, u.phone].some(x => (x || '').toLowerCase().includes(q))));
  $('#users').innerHTML = rows.map(u => `<tr>
    <td class="num">${u.id}</td>
    <td>${ROLE[u.role]}</td>
    <td><b>${esc(u.name)}</b></td>
    <td>${esc(u.email || '')}${u.email && u.phone ? '<br>' : ''}<span class="hint">${esc(u.phone || '')}</span></td>
    <td class="hint">${(u.linked || []).map(esc).join(', ')}</td>
    <td class="num hint">${fmtDate(u.created_at)}</td>
    <td>${u.active ? '<span class="pill taken">Hoạt động</span>' : '<span class="pill missed">Đã khóa</span>'}</td>
    <td class="row" style="justify-content:flex-end">${u.id === me.id || u.role === 'admin' ? '' : `
      <button class="btn sm" data-toggle="${u.id}">${u.active ? 'Khóa' : 'Mở khóa'}</button>
      <button class="btn sm danger" data-del="${u.id}">Xóa</button>`}</td>
  </tr>`).join('') || '<tr><td colspan="8" class="empty">Không có kết quả</td></tr>';
}

$('#users').onclick = async ev => {
  const t = ev.target.closest('[data-toggle]');
  const d = ev.target.closest('[data-del]');
  try {
    if (t) {
      const u = users.find(x => x.id === +t.dataset.toggle);
      await API.put(`/admin/users/${u.id}`, { active: !u.active });
      toast(u.active ? 'Đã khóa tài khoản' : 'Đã mở khóa');
      await load();
    } else if (d) {
      const u = users.find(x => x.id === +d.dataset.del);
      const extra = u.role === 'child' ? '\nHồ sơ bố mẹ chỉ do người này theo dõi cũng sẽ bị xóa.' : '';
      if (!confirm(`Xóa vĩnh viễn tài khoản “${u.name}”?${extra}`)) return;
      await API.del(`/admin/users/${u.id}`);
      toast('Đã xóa');
      await load();
    }
  } catch (ex) { toast(ex.message, 'error'); }
};
$('#role-filter').onchange = render;
$('#search').oninput = render;
$('#logout-btn').onclick = logout;

(async () => {
  me = await requireRole('admin');
  $('#me-name').textContent = me.name;
  await load();
})();
