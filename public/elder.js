// Trang của bố mẹ: thật đơn giản, chữ to, có giọng nói nhắc uống thuốc
const $ = s => document.querySelector(s);
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
const SNOOZE_MIN = 10;
const REPEAT_SEC = 60; // nhắc lại bằng giọng nói mỗi phút khi chưa xác nhận

let me, contacts = [], doses = [], grace = 60;
let started = false; // chỉ báo sau khi người dùng đã chạm (trình duyệt mới cho phát tiếng)
let alarmGroup = null, alarmKey = '', repeatTimer = null, recog = null;
let snoozed = {};
try { snoozed = JSON.parse(store.get('antam_snooze') || '{}'); } catch {}
const notified = new Set();

const key = d => `${d.date}|${d.med_id}|${d.time}`;
const call = () => me?.name || 'bạn';

// ---------------------------------------------------------------- âm thanh

let actx = null;
function unlockAudio() {
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    actx.resume();
  } catch {}
  // "Đánh thức" bộ đọc giọng nói bằng một câu rỗng trong lúc có thao tác chạm
  try { speechSynthesis.speak(new SpeechSynthesisUtterance('')); } catch {}
}

function chime() {
  if (!actx) return;
  [880, 660, 880].forEach((f, i) => {
    const o = actx.createOscillator(), g = actx.createGain();
    const s = actx.currentTime + i * 0.35;
    o.frequency.value = f;
    o.connect(g); g.connect(actx.destination);
    g.gain.setValueAtTime(0.0001, s);
    g.gain.exponentialRampToValueAtTime(0.5, s + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, s + 0.3);
    o.start(s); o.stop(s + 0.32);
  });
}

function viVoice() {
  const voices = speechSynthesis.getVoices();
  return voices.find(v => /^vi/i.test(v.lang) && /google|natural|online/i.test(v.name))
      || voices.find(v => /^vi/i.test(v.lang));
}

function speak(text, onEnd) {
  if (!('speechSynthesis' in window)) { onEnd?.(); return; }
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'vi-VN';
  const v = viVoice();
  if (v) u.voice = v;
  u.rate = 0.9;
  u.onend = () => onEnd?.();
  u.onerror = () => onEnd?.();
  speechSynthesis.speak(u);
}
if ('speechSynthesis' in window) speechSynthesis.onvoiceschanged = () => {};

// Nghe người già nói "đã uống" để xác nhận bằng giọng nói
function listen() {
  if (!SR || !alarmGroup) return;
  stopListening();
  recog = new SR();
  recog.lang = 'vi-VN';
  recog.interimResults = false;
  recog.maxAlternatives = 3;
  $('#listen').textContent = 'Đang nghe… hãy nói “đã uống”';
  $('#listen').classList.add('on');
  recog.onresult = ev => {
    const said = Array.from(ev.results[0]).map(a => a.transcript.toLowerCase()).join(' | ');
    if (/(uống rồi|đã uống|xong rồi|uống xong|rồi|xong|ok|được rồi)/.test(said)) confirmTaken();
    else if (/(lát|chút nữa|chờ|đợi|sau)/.test(said)) snooze();
  };
  recog.onend = () => { $('#listen').textContent = ''; $('#listen').classList.remove('on'); };
  try { recog.start(); } catch {}
}

function stopListening() {
  try { recog?.abort(); } catch {}
  recog = null;
}

// ---------------------------------------------------------------- dữ liệu

async function refresh() {
  try {
    const data = await API.get('/elder/today');
    me = data.me;
    contacts = data.contacts;
    doses = data.doses;
    grace = data.grace_minutes;
    render();
    tick();
  } catch (ex) {
    console.warn(ex);
  }
}

function dueTime(d) {
  const [h, m] = d.time.split(':').map(Number);
  const t = new Date();
  t.setHours(h, m, 0, 0);
  return t.getTime();
}

// Tính lại trạng thái ở máy (để báo đúng phút, không phải chờ máy chủ)
function liveStatus(d) {
  if (d.status === 'taken' || d.status === 'skipped') return d.status;
  const diff = (Date.now() - dueTime(d)) / 60000;
  if (diff < 0) return 'upcoming';
  if (diff <= grace) return 'due';
  return 'missed';
}

// ---------------------------------------------------------------- giao diện

function render() {
  $('#hello').textContent = `Chào ${call()}`;
  const list = doses.map(d => ({ ...d, live: liveStatus(d) }));

  // Ô lớn phía trên: lần uống tiếp theo
  const hero = $('#hero');
  const missed = list.filter(d => d.live === 'missed');
  const next = list.find(d => d.live === 'due' || d.live === 'upcoming');
  if (!list.length) {
    hero.className = 'e-hero done';
    hero.innerHTML = `<div class="lbl">Hôm nay</div><div class="big">Không có thuốc cần uống</div>`;
  } else if (next) {
    const group = list.filter(d => d.time === next.time && (d.live === 'due' || d.live === 'upcoming'));
    hero.className = 'e-hero';
    hero.innerHTML = `<div class="lbl">${next.live === 'due' ? 'Đến giờ uống rồi' : 'Lần uống tiếp theo'}</div>
      <div class="big">${next.time}</div>
      <div class="sub">${group.map(d => `${esc(d.name)}${d.dosage ? ` – ${esc(d.dosage)}` : ''}`).join('<br>')}</div>`;
  } else if (missed.length) {
    hero.className = 'e-hero late';
    hero.innerHTML = `<div class="lbl">Hôm nay</div><div class="big">Còn ${missed.length} lần chưa uống</div><div class="sub">Nếu đã uống, bấm “Tôi đã uống” bên dưới</div>`;
  } else {
    hero.className = 'e-hero done';
    hero.innerHTML = `<div class="lbl">Hôm nay</div><div class="big">Đã uống đủ thuốc 👏</div>`;
  }

  const icon = { taken: '✓', skipped: '–', missed: '!', due: '⏰', upcoming: '' };
  $('#doses').innerHTML = list.map(d => `
    <div class="e-dose ${d.live}">
      <div class="t">${d.time}</div>
      <div class="info">
        <div class="n">${esc(d.name)}</div>
        <div class="d">${[esc(d.dosage), esc(d.note)].filter(Boolean).join(' · ')}</div>
        ${d.live === 'missed' || d.live === 'due' ? `<button class="btn late-btn" data-take="${key(d)}">Tôi đã uống</button>` : ''}
      </div>
      <div class="st">${icon[d.live]}</div>
    </div>`).join('') || '<p class="e-date">Chưa có lịch.</p>';

  const c = contacts.find(x => x.phone);
  const cb = $('#call-btn');
  cb.hidden = !c;
  if (c) { cb.href = `tel:${c.phone}`; cb.querySelector('span').textContent = `Gọi cho ${c.name}`; }
}

function updateClock() {
  const now = new Date();
  $('#clock').textContent = now.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
  $('#date').textContent = now.toLocaleDateString('vi-VN', { weekday: 'long', day: 'numeric', month: 'numeric' });
}

// ---------------------------------------------------------------- báo thức

function tick() {
  const now = Date.now();
  const due = doses.filter(d => liveStatus(d) === 'due' && !(snoozed[key(d)] > now));
  if (due.length && started) openAlarm(due);
  else if (alarmGroup) closeAlarm();
  render();
}

function alarmSpeech(group) {
  const meds = group.map(d => `${d.name}${d.dosage ? ', ' + d.dosage : ''}`).join('. ');
  return `${call()} ơi, đến giờ uống thuốc rồi ạ. ${meds}. Uống xong, ${call()} bấm nút màu xanh`
    + (SR ? ', hoặc nói: đã uống.' : '.');
}

function ring() {
  if (!alarmGroup) return;
  chime();
  navigator.vibrate?.([400, 200, 400, 200, 400]);
  setTimeout(() => speak(alarmSpeech(alarmGroup), listen), 1100);
}

function openAlarm(group) {
  const k = group.map(key).join(',');
  if (k === alarmKey) return; // đang báo rồi
  alarmGroup = group;
  alarmKey = k;
  $('#alarm-meds').innerHTML = group.map(d => `<div class="med"><b>${esc(d.name)}</b><span>${[esc(d.dosage), esc(d.note)].filter(Boolean).join(' · ')}</span></div>`).join('');
  $('#alarm').hidden = false;
  ring();
  clearInterval(repeatTimer);
  repeatTimer = setInterval(ring, REPEAT_SEC * 1000);
  if (!notified.has(k)) {
    notified.add(k);
    showSystemNotification('Đến giờ uống thuốc', {
      body: group.map(d => `${d.time} ${d.name} ${d.dosage || ''}`).join('\n'),
      icon: '/icon.svg', tag: 'antam-' + k, requireInteraction: true, vibrate: [400, 200, 400],
      data: { url: '/elder.html' },
    });
  }
}

function closeAlarm() {
  alarmGroup = null;
  alarmKey = '';
  clearInterval(repeatTimer);
  stopListening();
  $('#alarm').hidden = true;
}

async function markTaken(list) {
  for (const d of list) {
    await API.post('/elder/doses', { med_id: d.med_id, time: d.time, status: 'taken' });
    d.status = 'taken';
  }
}

async function confirmTaken() {
  if (!alarmGroup) return;
  const group = alarmGroup;
  closeAlarm();
  try {
    await markTaken(group);
    speak(`Cảm ơn ${call()}. Đã ghi nhận ${call()} uống thuốc rồi ạ.`);
    toast('Đã ghi nhận ✓');
  } catch (ex) {
    toast(ex.message, 'error');
  }
  tick();
}

function snooze() {
  if (!alarmGroup) return;
  const until = Date.now() + SNOOZE_MIN * 60000;
  for (const d of alarmGroup) snoozed[key(d)] = until;
  store.set('antam_snooze', JSON.stringify(snoozed));
  closeAlarm();
  speak(`Vâng, ${SNOOZE_MIN} phút nữa tôi sẽ nhắc lại.`);
  render();
}

// ---------------------------------------------------------------- sự kiện

$('#taken-btn').onclick = confirmTaken;
$('#snooze-btn').onclick = snooze;
$('#doses').onclick = async ev => {
  const b = ev.target.closest('[data-take]');
  if (!b) return;
  const d = doses.find(x => key(x) === b.dataset.take);
  try {
    await markTaken([d]);
    speak(`Đã ghi nhận ${call()} uống ${d.name}.`);
    tick();
  } catch (ex) { toast(ex.message, 'error'); }
};
$('#help-btn').onclick = () => { $('#help').hidden = false; speak('Bấm nút màu đỏ để báo cho con biết.'); };
$('#help-no').onclick = () => { $('#help').hidden = true; };
$('#help-yes').onclick = async () => {
  try {
    await API.post('/elder/alert', { kind: 'help' });
    $('#help').hidden = true;
    speak('Đã báo cho con rồi ạ. Con sẽ gọi lại ngay.');
    toast('Đã báo cho con');
  } catch (ex) { toast(ex.message, 'error'); }
};
$('#test-voice').onclick = () => { unlockAudio(); chime(); setTimeout(() => speak(`${call()} ơi, đây là giọng nhắc uống thuốc.`), 1100); };
$('#logout-btn').onclick = () => { if (confirm('Đăng xuất? Sẽ cần nhập lại mã của con.')) logout(); };

function begin() {
  unlockAudio();
  started = true;
  $('#tap').hidden = true;
  $('#setup').hidden = true;
  tick();
}

$('#setup-btn').onclick = async () => {
  unlockAudio();
  try { if ('Notification' in window) await Notification.requestPermission(); } catch {}
  try {
    const s = await navigator.mediaDevices.getUserMedia({ audio: true });
    s.getTracks().forEach(t => t.stop());
  } catch {}
  store.set('antam_setup', '1');
  begin();
  speak(`Chào ${call()}. Từ nay đến giờ uống thuốc, tôi sẽ nhắc ${call()}.`);
};
$('#tap-btn').onclick = begin;

// Khi quay lại app (mở từ thông báo) thì cập nhật ngay
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });

(async () => {
  me = await requireRole('elder');
  await registerSW();
  updateClock();
  setInterval(updateClock, 1000);
  await refresh();
  if (!store.get('antam_setup')) $('#setup').hidden = false;
  else $('#tap').hidden = false;
  setInterval(refresh, 60000);
  setInterval(tick, 10000);
})();
