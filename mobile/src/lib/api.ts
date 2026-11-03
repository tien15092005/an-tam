import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { storage } from './storage';

const SERVER_PORT = 8000;
let token: string | null = null;
let baseUrl: string | null = null;

// Khi chạy bằng Expo Go, điện thoại kết nối tới máy tính đang chạy "npx expo start".
// Server Python chạy trên cùng máy tính đó, nên lấy IP máy tính từ hostUri.
function guessServerUrl() {
  if (Platform.OS === 'web') return `http://localhost:${SERVER_PORT}`;
  const host =
    Constants.expoConfig?.hostUri ??
    (Constants as any).expoGoConfig?.debuggerHost ??
    (Constants as any).manifest2?.extra?.expoGo?.debuggerHost;
  const ip = host ? String(host).split(':')[0] : 'localhost';
  return `http://${ip}:${SERVER_PORT}`;
}

export async function initApi() {
  token = await storage.get('token');
  baseUrl = (await storage.get('server_url')) || guessServerUrl();
  return token;
}

export function getServerUrl() {
  return baseUrl || guessServerUrl();
}

export async function setServerUrl(url: string) {
  const clean = url.trim().replace(/\/+$/, '');
  baseUrl = clean || guessServerUrl();
  if (clean) await storage.set('server_url', clean);
  else await storage.del('server_url');
}

export async function setToken(t: string | null) {
  token = t;
  if (t) await storage.set('token', t);
  else await storage.del('token');
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

let onUnauthorized: (() => void) | null = null;
export function setUnauthorizedHandler(fn: () => void) {
  onUnauthorized = fn;
}

async function req<T = any>(method: string, path: string, body?: any): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  let res: Response;
  try {
    res = await fetch(`${getServerUrl()}/api${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, `Không kết nối được máy chủ (${getServerUrl()}). Kiểm tra máy tính và điện thoại dùng chung Wi-Fi.`);
  }
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && !path.startsWith('/auth/')) onUnauthorized?.();
  if (!res.ok) throw new ApiError(res.status, data.error || 'Có lỗi xảy ra');
  return data as T;
}

export const api = {
  get: <T = any>(p: string) => req<T>('GET', p),
  post: <T = any>(p: string, b: any = {}) => req<T>('POST', p, b),
  put: <T = any>(p: string, b: any = {}) => req<T>('PUT', p, b),
  del: <T = any>(p: string) => req<T>('DELETE', p),
};

// ---------- kiểu dữ liệu trả về từ server

export type Role = 'admin' | 'child' | 'elder';
export type User = { id: number; role: Role; name: string; email?: string; phone?: string };
export type Status = 'taken' | 'skipped' | 'missed' | 'due' | 'upcoming' | 'done';

export type Dose = {
  med_id: number; name: string; dosage: string; note: string; date: string; time: string;
  status: Status; logged_at: string | null; logged_by: { role: Role; name: string } | null;
};
export type ExerciseItem = {
  exercise_id: number; title: string; duration_min: number; note: string; date: string; time: string;
  status: Status; logged_at: string | null;
};
export type Summary = { total: number; taken: number; skipped: number; missed: number; due: number; upcoming: number; next: Dose | null };
export type Elder = {
  id: number; name: string; phone: string; birth_year: number | null; note: string; login_code?: string;
  today?: Summary; alerts?: { id: number; kind: string; created_at: string }[];
  latest_health?: Record<string, HealthRecord>;
};
export type HealthRecord = { id: number; type: string; value: number; value2: number | null; note: string; recorded_at: string; by_name?: string };
export type CalendarDay = { date: string; doses: Dose[]; exercises: ExerciseItem[]; summary: Summary };
export type Medication = { id: number; name: string; dosage: string; note: string; times: string[]; start_date: string | null; end_date: string | null };
export type Exercise = { id: number; title: string; time: string; days: number[]; duration_min: number; note: string; start_date: string | null; end_date: string | null };
export type OcrItem = { name: string; dosage: string; times: string[]; days: number | null; note: string };
