// Tiện ích ngày giờ (luôn dùng chuỗi 'YYYY-MM-DD' theo giờ địa phương)
export const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
export const WEEKDAY_FULL = ['Chủ nhật', 'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy'];
// Server dùng 1 = Thứ 2 ... 7 = Chủ nhật
export const ISO_DAYS = [
  { v: 1, label: 'T2' }, { v: 2, label: 'T3' }, { v: 3, label: 'T4' }, { v: 4, label: 'T5' },
  { v: 5, label: 'T6' }, { v: 6, label: 'T7' }, { v: 7, label: 'CN' },
];

const pad = (n: number) => String(n).padStart(2, '0');

export function toISO(d: Date) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function fromISO(s: string) {
  const [y, m, d] = s.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function addDays(s: string, n: number) {
  const d = fromISO(s);
  d.setDate(d.getDate() + n);
  return toISO(d);
}

export function today() {
  return toISO(new Date());
}

// Thứ 2 đầu tuần chứa ngày s
export function startOfWeek(s: string) {
  const d = fromISO(s);
  const dow = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - dow);
  return toISO(d);
}

export function dayLabel(s: string) {
  const d = fromISO(s);
  const t = today();
  const prefix = s === t ? 'Hôm nay' : s === addDays(t, 1) ? 'Ngày mai' : s === addDays(t, -1) ? 'Hôm qua' : WEEKDAY_FULL[d.getDay()];
  return `${prefix}, ${d.getDate()}/${d.getMonth() + 1}`;
}

export function shortDate(s: string) {
  const d = fromISO(s.slice(0, 10));
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
}

export function timeOf(iso: string | null) {
  return iso ? iso.slice(11, 16) : '';
}

export function greeting() {
  const h = new Date().getHours();
  if (h < 11) return 'Chào buổi sáng';
  if (h < 14) return 'Chào buổi trưa';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

export function isValidTime(t: string) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(t);
}

// "730" -> "07:30", "7:5" -> "07:05"
export function normalizeTime(t: string) {
  const s = t.replace(/[^\d:]/g, '');
  const m = s.includes(':') ? s.split(':') : s.length <= 2 ? [s, '00'] : [s.slice(0, -2), s.slice(-2)];
  const out = `${pad(Number(m[0] || 0))}:${pad(Number(m[1] || 0))}`;
  return isValidTime(out) ? out : null;
}
