import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';

export const CHANNEL_ID = 'reminders';

export type Reminder = { kind: 'dose' | 'exercise'; date: string; time: string; id: number; title: string; detail: string };

// Hiện thông báo kèm âm thanh cả khi app đang mở
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function setupNotifications() {
  if (Platform.OS === 'web') return false;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
      name: 'Nhắc uống thuốc & tập thể dục',
      // eslint-disable-next-line import/namespace -- được export lại từ expo-notifications (tsc kiểm tra OK)
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 500, 300, 500, 300, 500],
      sound: 'default',
    });
  }
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  const res = await Notifications.requestPermissionsAsync({
    ios: { allowAlert: true, allowBadge: false, allowSound: true },
  });
  return res.granted;
}

// Đặt lại toàn bộ lịch nhắc cục bộ: điện thoại sẽ tự báo đúng giờ kể cả khi app đã đóng
export async function scheduleReminders(list: Reminder[], elderName: string) {
  if (Platform.OS === 'web') return;
  await Notifications.cancelAllScheduledNotificationsAsync();
  const now = Date.now();
  // Gộp các thuốc cùng giờ thành một thông báo
  const groups = new Map<string, Reminder[]>();
  for (const r of list) {
    const k = `${r.date} ${r.time} ${r.kind}`;
    groups.set(k, [...(groups.get(k) || []), r]);
  }
  let count = 0;
  for (const [, items] of groups) {
    const [y, m, d] = items[0].date.split('-').map(Number);
    const [hh, mm] = items[0].time.split(':').map(Number);
    const at = new Date(y, m - 1, d, hh, mm, 0);
    if (at.getTime() <= now || count >= 60) continue; // iOS giới hạn 64 thông báo chờ
    const isDose = items[0].kind === 'dose';
    await Notifications.scheduleNotificationAsync({
      content: {
        title: isDose ? `💊 ${elderName} ơi, đến giờ uống thuốc` : `🚶 ${elderName} ơi, đến giờ tập thể dục`,
        body: items.map(i => `${i.title}${i.detail ? ` – ${i.detail}` : ''}`).join('\n'),
        sound: 'default',
        data: { kind: items[0].kind },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: at,
        channelId: CHANNEL_ID,
      },
    });
    count++;
  }
}

export async function clearReminders() {
  if (Platform.OS === 'web') return;
  await Notifications.cancelAllScheduledNotificationsAsync();
}
