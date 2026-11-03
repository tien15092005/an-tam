import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';

// SecureStore trên điện thoại, localStorage khi chạy thử trên web
export const storage = {
  async get(key: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      try { return localStorage.getItem(key); } catch { return null; }
    }
    return SecureStore.getItemAsync(key);
  },
  async set(key: string, value: string) {
    if (Platform.OS === 'web') {
      try { localStorage.setItem(key, value); } catch {}
      return;
    }
    await SecureStore.setItemAsync(key, value);
  },
  async del(key: string) {
    if (Platform.OS === 'web') {
      try { localStorage.removeItem(key); } catch {}
      return;
    }
    await SecureStore.deleteItemAsync(key);
  },
};
