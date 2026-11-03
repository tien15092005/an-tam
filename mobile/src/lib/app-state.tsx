import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, initApi, setToken, setUnauthorizedHandler, type Elder, type User } from './api';
import { clearReminders } from './notifications';
import { storage } from './storage';

type AppState = {
  ready: boolean;
  user: User | null;
  signIn: (token: string, user: User) => Promise<void>;
  signOut: () => Promise<void>;
  // Phía người con: danh sách bố mẹ và người đang được chọn
  elders: Elder[];
  elder: Elder | null;
  selectElder: (id: number) => void;
  reloadElders: () => Promise<Elder[]>;
};

const Ctx = createContext<AppState>(null as any);

export function AppProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [elders, setElders] = useState<Elder[]>([]);
  const [elderId, setElderId] = useState<number | null>(null);

  const signOut = useCallback(async () => {
    try { await api.post('/auth/logout'); } catch {}
    await setToken(null);
    await clearReminders();
    setUser(null);
    setElders([]);
    setElderId(null);
  }, []);

  useEffect(() => {
    setUnauthorizedHandler(() => {
      setToken(null);
      setUser(null);
    });
    (async () => {
      const token = await initApi();
      if (token) {
        try { setUser(await api.get<User>('/me')); } catch { await setToken(null); }
      }
      const saved = await storage.get('elder_id');
      if (saved) setElderId(Number(saved));
      setReady(true);
    })();
  }, []);

  const signIn = useCallback(async (token: string, u: User) => {
    await setToken(token);
    setUser(u);
  }, []);

  const reloadElders = useCallback(async () => {
    const list = await api.get<Elder[]>('/elders');
    setElders(list);
    setElderId(cur => (list.some(e => e.id === cur) ? cur : list[0]?.id ?? null));
    return list;
  }, []);

  // Người con: tải danh sách bố mẹ ngay sau khi đăng nhập, mọi màn hình (kể cả form mở trực tiếp) đều có dữ liệu
  useEffect(() => {
    if (user?.role !== 'child') return;
    const t = setTimeout(() => { reloadElders().catch(() => {}); }, 0);
    return () => clearTimeout(t);
  }, [user, reloadElders]);

  const selectElder = useCallback((id: number) => {
    setElderId(id);
    storage.set('elder_id', String(id));
  }, []);

  const elder = elders.find(e => e.id === elderId) || null;

  return (
    <Ctx.Provider value={{ ready, user, signIn, signOut, elders, elder, selectElder, reloadElders }}>
      {children}
    </Ctx.Provider>
  );
}

export const useApp = () => useContext(Ctx);
