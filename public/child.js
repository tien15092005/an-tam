// Trang của người con: theo dõi bố mẹ, quản lý thuốc, sức khỏe
const $ = s => document.querySelector(s);
const dlg = $('#dlg');

const HT = {
  bp:     { label: 'Huyết áp',    unit: 'mmHg',     bad: r => r.value >= 140 || r.value < 90 || r.value2 >= 90 || r.value2 < 60 },
  hr:     { label: 'Nhịp tim',    unit: 'lần/phút', bad: r => r.value < 60 || r.value > 100 },
  sugar:  { label: 'Đường huyết', unit: 'mmol/L',   bad: r => r.value < 3.9 || r.value > 7 },
  spo2:   { label: 'SpO₂',        unit: '%',        bad: r => r.value < 95 },
  temp:   { label: 'Nhiệt độ',    unit: '°C',       bad: r => r.value < 36 || r.value >= 37.6 },
  weight: { label: 'Cân nặng',    unit: 'kg',       bad: () => false },
};
const STATUS = { taken: 'Đã uống', skipped: 'Bỏ qua', missed: 'Quên uống', due: 'Đang đến giờ', upcoming: 'Sắp tới' };
const TABS = [['today', 'Hôm nay'], ['meds', 'Thuốc'], ['health', 'Sức khỏe'], ['history', 'Lịch sử'], ['settings', 'Cài đặt']];

let me, elders = [], currentId = null, tab = 'today';
const seen = new Set();
let firstLoad = true;

const num = v => (v == null ? '' : String(+(+v).toFixed(1)));
const healthVal = r => (r.type === 'bp' ? `${num(r.value)}/${num(r.value2)}` : num(r.value));
const current = () => elders.find(e => e.id === currentId);

// ---------------------------------------------------------------- load

async function loadElders() {
  elders = await API.get('/elders');
  if (!current()) currentId = elders[0]?.id ?? null;
  checkNewProblems();
  renderSidebar();
}

function checkNewProblems() {
  for (const e of elders) {
    const keys = [];
    for (const a of e.alerts) keys.push(['a' + a.id, `${e.name} báo: cần giúp đỡ!`, 'Mở ứng dụng để xem và gọi lại ngay.']);
    if (e.today.missed) keys.push([`m${e.id}-${e.today.missed}-${new Date().toDateString()}`,
      `${e.name} chưa uống thuốc`, `Có ${e.today.missed} lần uống bị quên hôm nay.`]);
    for (const [k, title, body] of keys) {
      if (!seen.has(k) && !firstLoad) {
        showSystemNotification(title, { body, icon: '/icon.svg', tag: k, data: { url: '/child.html' } });
        toast(title, 'error');
      }
      seen.add(k);
    }
  }
  firstLoad = false;
}

// ---------------------------------------------------------------- render

function renderSidebar() {
  $('#elder-list').innerHTML = elders.map(e => {
    const t = e.today;
    const color = e.alerts.length || t.missed ? 'red' : t.due ? 'amber' : 'green';
    return `<button class="elder-item ${e.id === currentId ? 'active' : ''}" data-act="select" data-id="${e.id}">
      <b>${esc(e.name)}</b>
      <span class="meta"><span class="dot ${color}"></span>Đã uống ${t.taken}/${t.total}
        ${t.missed ? `· <span class="flag">Quên ${t.missed}</span>` : ''}
        ${e.alerts.length ? '· <span class="flag">Cần giúp!</span>' : ''}</span>
    </button>`;
  }).join('') || '<p class="hint" style="margin:4px 4px 12px">Chưa có hồ sơ nào.</p>';
}

async function renderMain() {
  const e = current();
  const main = $('#main');
  if (!e) {
    main.innerHTML = `<div class="card empty">
      <h2>Chào ${esc(me.name)} 👋</h2>
      <p>Bắt đầu bằng cách tạo hồ sơ cho bố hoặc mẹ. Ứng dụng sẽ cho bạn một <b>mã 6 số</b> để cài trên điện thoại của bố mẹ.</p>
      <button class="btn primary" data-act="add-elder">+ Thêm bố / mẹ</button></div>`;
    return;
  }
  const t = e.today;
  const bp = e.latest_health.bp;
  const age = e.birth_year ? `${new Date().getFullYear() - e.birth_year} tuổi` : '';
  main.innerHTML = `
    <div class="head">
      <div><h2>${esc(e.name)}</h2><div class="hint">${[age, esc(e.phone), esc(e.note)].filter(Boolean).join(' · ')}</div></div>
      ${e.phone ? `<a class="btn" href="tel:${esc(e.phone)}">📞 Gọi</a>` : ''}
    </div>
    ${e.alerts.map(a => `<div class="alert-banner">
      <span>🚨 <b>${esc(e.name)} bấm “Tôi thấy không khỏe”</b> lúc ${fmtDateTime(a.created_at)}</span>
      <span class="row">${e.phone ? `<a class="btn sm" href="tel:${esc(e.phone)}">Gọi ngay</a>` : ''}
      <button class="btn sm" data-act="resolve" data-id="${a.id}">Đã xử lý</button></span></div>`).join('')}
    <div class="stats">
      <div class="stat good"><div class="k">Đã uống hôm nay</div><div class="v">${t.taken}<small> / ${t.total}</small></div></div>
      <div class="stat ${t.missed ? 'bad' : ''}"><div class="k">Quên uống</div><div class="v">${t.missed}</div></div>
      <div class="stat"><div class="k">Lần tiếp theo</div><div class="v" style="font-size:20px;padding-top:4px">${t.next ? `${t.next.time} <small>${esc(t.next.name)}</small>` : '—'}</div></div>
      <div class="stat ${bp && HT.bp.bad(bp) ? 'bad' : ''}"><div class="k">Huyết áp gần nhất</div><div class="v" style="font-size:22px;padding-top:2px">${bp ? healthVal(bp) : '—'} <small>${bp ? fmtDate(bp.recorded_at) : ''}</small></div></div>
    </div>
    <nav class="subtabs">${TABS.map(([k, l]) => `<button class="${k === tab ? 'active' : ''}" data-act="tab" data-tab="${k}">${l}</button>`).join('')}</nav>
    <section id="tab-body"><div class="empty">Đang tải…</div></section>`;
  await renderTab();
}

async function renderTab() {
  const body = $('#tab-body');
  if (!body) return;
  try {
    body.innerHTML = await VIEWS[tab](current());
  } catch (ex) {
    body.innerHTML = `<div class="empty">${esc(ex.message)}</div>`;
  }
}

function doseRow(d, actions) {
  let who = '';
  if (d.logged_by && d.logged_at) {
    const t = d.logged_at.slice(11, 16);
    who = d.logged_by.role === 'elder' ? `Tự xác nhận lúc ${t}` : `${esc(d.logged_by.name)} đánh dấu lúc ${t}`;
  }
  return `<div class="dose">
    <div class="t">${d.time}</div>
    <div><div class="n">${esc(d.name)} <span class="pill ${d.status}">${STATUS[d.status]}</span></div>
      <div class="d">${[esc(d.dosage), esc(d.note), who].filter(Boolean).join(' · ')}</div></div>
    <div class="row">${actions}</div>
  </div>`;
}

const VIEWS = {
  async today(e) {
    const doses = await API.get(`/elders/${e.id}/today`);
    if (!doses.length) return `<div class="card empty">Hôm nay chưa có lịch uống thuốc. Vào tab <b>Thuốc</b> để thêm.</div>`;
    return `<div class="dose-list">${doses.map(d => doseRow(d,
      d.status === 'taken' || d.status === 'skipped'
        ? `<button class="btn sm ghost" data-act="dose" data-med="${d.med_id}" data-time="${d.time}" data-status="clear">Hoàn tác</button>`
        : `<button class="btn sm" data-act="dose" data-med="${d.med_id}" data-time="${d.time}" data-status="taken">✓ Đã uống</button>
           <button class="btn sm ghost" data-act="dose" data-med="${d.med_id}" data-time="${d.time}" data-status="skipped">Bỏ qua</button>`
    )).join('')}</div>
    <p class="hint">Quá ${60} phút sau giờ uống mà chưa xác nhận sẽ tính là “Quên uống”. Bạn có thể đánh dấu giúp nếu đã gọi điện hỏi bố mẹ.</p>`;
  },

  async meds(e) {
    const meds = await API.get(`/elders/${e.id}/medications`);
    VIEWS._meds = meds;
    return `<div class="section-title"><h3>Đơn thuốc đang dùng</h3><button class="btn primary" data-act="add-med">+ Thêm thuốc</button></div>
      ${meds.length ? `<div class="dose-list">${meds.map(m => `<div class="card med-card">
        <div><b style="font-size:17px">${esc(m.name)}</b> <span class="hint">${esc(m.dosage)}</span>
          ${m.note ? `<div class="hint">${esc(m.note)}</div>` : ''}
          <div class="times">${m.times.map(t => `<span>⏰ ${t}</span>`).join('')}</div></div>
        <div class="row"><button class="btn sm" data-act="edit-med" data-id="${m.id}">Sửa</button>
          <button class="btn sm danger" data-act="del-med" data-id="${m.id}">Xóa</button></div>
      </div>`).join('')}</div>` : '<div class="card empty">Chưa có thuốc nào.</div>'}`;
  },

  async health(e) {
    const recs = await API.get(`/elders/${e.id}/health?days=60`);
    const latest = e.latest_health;
    return `<div class="section-title"><h3>Chỉ số gần nhất</h3><button class="btn primary" data-act="add-health">+ Ghi chỉ số</button></div>
      <div class="stats">${Object.entries(HT).map(([k, h]) => {
        const r = latest[k];
        return `<div class="stat ${r && h.bad(r) ? 'bad' : ''}"><div class="k">${h.label}</div>
          <div class="v" style="font-size:22px">${r ? healthVal(r) : '—'} <small>${r ? h.unit : ''}</small></div>
          <div class="hint">${r ? fmtDateTime(r.recorded_at) : 'Chưa có'}</div></div>`;
      }).join('')}</div>
      <h3>Nhật ký (60 ngày)</h3>
      ${recs.length ? `<div class="table-wrap"><table>
        <thead><tr><th>Thời gian</th><th>Chỉ số</th><th>Giá trị</th><th>Ghi chú</th><th></th></tr></thead>
        <tbody>${recs.map(r => `<tr>
          <td class="num">${fmtDateTime(r.recorded_at)}</td><td>${HT[r.type]?.label || r.type}</td>
          <td class="num ${HT[r.type]?.bad(r) ? 'flag' : ''}">${healthVal(r)} <span class="hint">${HT[r.type]?.unit || ''}</span></td>
          <td>${esc(r.note)}</td>
          <td><button class="btn sm ghost" data-act="del-health" data-id="${r.id}" title="Xóa">✕</button></td></tr>`).join('')}
        </tbody></table></div>` : '<div class="card empty">Chưa có dữ liệu.</div>'}
      <p class="hint">Chữ đỏ = ngoài ngưỡng tham khảo thông thường. Đây không phải chẩn đoán y khoa — hãy hỏi bác sĩ khi có bất thường.</p>`;
  },

  async history(e) {
    const days = await API.get(`/elders/${e.id}/history?days=14`);
    const done = days.reduce((a, d) => a + d.taken + d.skipped + d.missed, 0);
    const taken = days.reduce((a, d) => a + d.taken, 0);
    return `<div class="section-title"><h3>14 ngày gần đây</h3>
      <span class="hint">Tỉ lệ uống đúng: <b style="color:var(--ink)">${done ? Math.round(100 * taken / done) : 0}%</b></span></div>
      <div class="table-wrap"><table>
      <thead><tr><th>Ngày</th><th>Tỉ lệ</th><th>Đã uống</th><th>Quên</th><th>Chi tiết quên</th></tr></thead>
      <tbody>${days.map(d => `<tr>
        <td class="num">${fmtDate(d.date)}</td>
        <td>${d.rate == null ? '<span class="hint">—</span>' : `<div class="row"><div class="hbar"><i style="width:${d.rate}%"></i></div><span class="num">${d.rate}%</span></div>`}</td>
        <td class="num">${d.taken}/${d.total}</td>
        <td class="num ${d.missed ? 'flag' : ''}">${d.missed}</td>
        <td class="hint">${d.doses.filter(x => x.status === 'missed').map(x => `${x.time} ${esc(x.name)}`).join(', ')}</td>
      </tr>`).join('')}</tbody></table></div>`;
  },

  async settings(e) {
    const detail = await API.get(`/elders/${e.id}`);
    return `<div class="dose-list">
      <div class="card">
        <h3>Mã đăng nhập cho ${esc(e.name)}</h3>
        <div class="code-box">${esc(detail.login_code)}</div>
        <p class="hint">Trên điện thoại của bố mẹ: mở ứng dụng → chọn <b>“Tôi là bố / mẹ”</b> → nhập mã này. Chỉ cần làm một lần.</p>
        <button class="btn" data-act="regen">Tạo mã mới</button>
        <span class="hint">(mã cũ và các máy đã đăng nhập sẽ bị đăng xuất)</span>
      </div>
      <div class="card">
        <h3>Thông tin</h3>
        <form id="profile-form">
          <div class="grid2">
            <div><label>Tên gọi</label><input name="name" value="${esc(detail.name)}" required></div>
            <div><label>Năm sinh</label><input name="birth_year" inputmode="numeric" value="${esc(detail.birth_year)}"></div>
          </div>
          <label>Số điện thoại</label><input name="phone" type="tel" value="${esc(detail.phone)}">
          <label>Ghi chú sức khỏe</label><textarea name="note" rows="2">${esc(detail.note)}</textarea>
          <div class="error"></div>
          <button class="btn primary">Lưu thay đổi</button>
        </form>
      </div>
      <div class="card">
        <h3>Người cùng theo dõi</h3>
        <ul>${detail.members.map(m => `<li>${esc(m.name)} <span class="hint">${esc(m.email)}</span></li>`).join('')}</ul>
        <form id="share-form" class="row">
          <input class="grow" name="email" type="email" placeholder="Email anh/chị/em đã đăng ký" required style="flex:1;min-width:200px">
          <button class="btn">Mời theo dõi</button>
        </form>
        <div class="error" id="share-err"></div>
      </div>
      <div class="card">
        <h3>Xóa hồ sơ</h3>
        <p class="hint">Bạn sẽ ngừng theo dõi hồ sơ này. Nếu không còn ai theo dõi, toàn bộ dữ liệu sẽ bị xóa.</p>
        <button class="btn danger" data-act="del-elder">Xóa hồ sơ</button>
      </div>
    </div>`;
  },
};

// ---------------------------------------------------------------- dialogs

function openDialog(title, fields, onSubmit, submitLabel = 'Lưu') {
  dlg.innerHTML = `<form><h2>${title}</h2>${fields}<div class="error"></div>
    <div class="actions"><button type="button" class="btn" data-close>Hủy</button><button class="btn primary">${submitLabel}</button></div></form>`;
  const form = dlg.querySelector('form');
  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    const btn = form.querySelector('button.primary');
    btn.disabled = true;
    try {
      await onSubmit(form);
      dlg.close();
    } catch (ex) {
      form.querySelector('.error').textContent = ex.message;
    } finally {
      btn.disabled = false;
    }
  });
  dlg.querySelector('[data-close]').onclick = () => dlg.close();
  dlg.showModal();
}

function elderDialog() {
  openDialog('Thêm bố / mẹ', `
    <label>Tên gọi <span class="hint">(giọng nhắc sẽ gọi theo tên này, vd: “Bà Lan”, “Bố”)</span></label>
    <input name="name" required autofocus>
    <div class="grid2">
      <div><label>Năm sinh</label><input name="birth_year" inputmode="numeric"></div>
      <div><label>Số điện thoại</label><input name="phone" type="tel"></div>
    </div>
    <label>Ghi chú sức khỏe</label><textarea name="note" rows="2" placeholder="Bệnh nền, dị ứng thuốc…"></textarea>`,
  async form => {
    const e = await API.post('/elders', Object.fromEntries(new FormData(form)));
    currentId = e.id;
    tab = 'settings';
    await refresh();
    toast(`Đã tạo hồ sơ. Mã đăng nhập: ${e.login_code}`);
  }, 'Tạo hồ sơ');
}

function timeRow(v = '') {
  return `<div class="time-row"><input type="time" name="times" value="${v}" required><button type="button" class="btn sm ghost" data-rm-time>✕</button></div>`;
}

function medDialog(med) {
  openDialog(med ? 'Sửa thuốc' : 'Thêm thuốc', `
    <label>Tên thuốc</label><input name="name" required value="${esc(med?.name)}">
    <label>Liều dùng</label><input name="dosage" placeholder="vd: 5mg - 1 viên" value="${esc(med?.dosage)}">
    <label>Giờ uống trong ngày</label>
    <div id="times">${(med?.times || ['08:00']).map(timeRow).join('')}</div>
    <button type="button" class="btn sm" id="add-time">+ Thêm giờ</button>
    <label>Ghi chú</label><input name="note" placeholder="vd: uống sau ăn" value="${esc(med?.note)}">`,
  async form => {
    const fd = new FormData(form);
    const body = { name: fd.get('name'), dosage: fd.get('dosage'), note: fd.get('note'), times: fd.getAll('times').filter(Boolean) };
    if (med) await API.put(`/medications/${med.id}`, body);
    else await API.post(`/elders/${currentId}/medications`, body);
    toast('Đã lưu thuốc');
    await refresh();
  });
  $('#add-time').onclick = () => $('#times').insertAdjacentHTML('beforeend', timeRow());
  $('#times').onclick = ev => {
    if (ev.target.matches('[data-rm-time]') && $('#times').children.length > 1) ev.target.parentElement.remove();
  };
}

function healthDialog() {
  const now = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  openDialog('Ghi chỉ số sức khỏe', `
    <label>Loại chỉ số</label>
    <select name="type" id="h-type">${Object.entries(HT).map(([k, h]) => `<option value="${k}">${h.label} (${h.unit})</option>`).join('')}</select>
    <div class="grid2">
      <div><label id="h-v1">Tâm thu</label><input name="value" inputmode="decimal" required></div>
      <div id="h-v2wrap"><label>Tâm trương</label><input name="value2" inputmode="decimal"></div>
    </div>
    <label>Thời gian đo</label><input type="datetime-local" name="recorded_at" value="${now}">
    <label>Ghi chú</label><input name="note">`,
  async form => {
    const fd = Object.fromEntries(new FormData(form));
    fd.value = String(fd.value).replace(',', '.');
    if (fd.value2) fd.value2 = String(fd.value2).replace(',', '.');
    await API.post(`/elders/${currentId}/health`, fd);
    toast('Đã ghi chỉ số');
    await refresh();
  });
  const sync = () => {
    const bp = $('#h-type').value === 'bp';
    $('#h-v2wrap').hidden = !bp;
    $('#h-v2wrap input').required = bp;
    $('#h-v1').textContent = bp ? 'Tâm thu' : 'Giá trị';
  };
  $('#h-type').onchange = sync;
  sync();
}

// ---------------------------------------------------------------- actions

async function refresh() {
  await loadElders();
  await renderMain();
}

document.addEventListener('click', async ev => {
  const el = ev.target.closest('[data-act]');
  if (!el) return;
  const id = el.dataset.id;
  try {
    switch (el.dataset.act) {
      case 'select': currentId = +id; renderSidebar(); await renderMain(); break;
      case 'tab': tab = el.dataset.tab; await renderMain(); break;
      case 'add-elder': elderDialog(); break;
      case 'add-med': medDialog(); break;
      case 'edit-med': medDialog(VIEWS._meds.find(m => m.id === +id)); break;
      case 'del-med':
        if (confirm('Xóa thuốc này khỏi lịch nhắc?')) { await API.del(`/medications/${id}`); toast('Đã xóa'); await refresh(); }
        break;
      case 'add-health': healthDialog(); break;
      case 'del-health':
        if (confirm('Xóa bản ghi này?')) { await API.del(`/health/${id}`); await refresh(); }
        break;
      case 'dose':
        await API.post(`/elders/${currentId}/doses`, { med_id: +el.dataset.med, time: el.dataset.time, status: el.dataset.status });
        await refresh();
        break;
      case 'resolve': await API.post(`/alerts/${id}/resolve`); await refresh(); break;
      case 'regen':
        if (confirm('Tạo mã mới? Điện thoại của bố mẹ sẽ phải nhập lại mã.')) { await API.post(`/elders/${currentId}/regen-code`); await renderTab(); }
        break;
      case 'del-elder':
        if (confirm('Bạn chắc chắn muốn xóa hồ sơ này?')) {
          await API.del(`/elders/${currentId}`);
          currentId = null; tab = 'today';
          await refresh();
        }
        break;
    }
  } catch (ex) {
    toast(ex.message, 'error');
  }
});

document.addEventListener('submit', async ev => {
  const form = ev.target;
  if (form.id === 'profile-form') {
    ev.preventDefault();
    try {
      await API.put(`/elders/${currentId}`, Object.fromEntries(new FormData(form)));
      toast('Đã lưu');
      await refresh();
    } catch (ex) { form.querySelector('.error').textContent = ex.message; }
  } else if (form.id === 'share-form') {
    ev.preventDefault();
    try {
      await API.post(`/elders/${currentId}/share`, Object.fromEntries(new FormData(form)));
      toast('Đã thêm người cùng theo dõi');
      await renderTab();
    } catch (ex) { $('#share-err').textContent = ex.message; }
  }
});

// ---------------------------------------------------------------- start

(async () => {
  me = await requireRole('child');
  $('#me-name').textContent = me.name;
  $('#logout-btn').onclick = logout;
  $('#add-elder').onclick = elderDialog;
  await registerSW();
  const nb = $('#notif-btn');
  if ('Notification' in window && Notification.permission === 'default') {
    nb.hidden = false;
    nb.onclick = async () => { await Notification.requestPermission(); nb.hidden = true; };
  }
  await refresh();
  // Cập nhật mỗi phút; không vẽ lại khi đang mở hộp thoại hoặc đang sửa form
  setInterval(async () => {
    try {
      await loadElders();
      if (!dlg.open && !document.activeElement?.closest('form')) await renderMain();
    } catch {}
  }, 60000);
})();
