import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import * as Notifications from 'expo-notifications';
import { Redirect, router } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, Animated, AppState, Easing, Linking, Modal, Pressable, ScrollView, StyleSheet, Vibration, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Loading, T } from '@/components/ui';
import { api, type Dose, type ExerciseItem } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { WEEKDAY_FULL, greeting } from '@/lib/format';
import { scheduleReminders, setupNotifications, type Reminder } from '@/lib/notifications';
import { hasVietnameseVoice, speak, stopSpeaking } from '@/lib/speech';
import { storage } from '@/lib/storage';
import { C, R } from '@/lib/theme';

type TodayData = {
  me: { name: string };
  grace_minutes: number;
  doses: Dose[];
  exercises: ExerciseItem[];
  contacts: { name: string; phone: string }[];
};
type Item = { kind: 'dose' | 'exercise'; key: string; time: string; title: string; detail: string; status: string; raw: Dose | ExerciseItem };

const SNOOZE_MIN = 10;
const REPEAT_MS = 60_000;

function dueAt(time: string) {
  const [h, m] = time.split(':').map(Number);
  const d = new Date();
  d.setHours(h, m, 0, 0);
  return d.getTime();
}

// Tính trạng thái ngay trên máy để báo đúng phút
function liveStatus(status: string, time: string, grace: number) {
  if (['taken', 'skipped', 'done'].includes(status)) return status;
  const diff = (Date.now() - dueAt(time)) / 60000;
  if (diff < 0) return 'upcoming';
  return diff <= grace ? 'due' : 'missed';
}

function toItems(data: TodayData | null): Item[] {
  if (!data) return [];
  const g = data.grace_minutes;
  return [
    ...data.doses.map(d => ({ kind: 'dose' as const, key: `d${d.med_id}-${d.time}`, time: d.time, title: d.name, detail: [d.dosage, d.note].filter(Boolean).join(' · '), status: liveStatus(d.status, d.time, g), raw: d })),
    ...data.exercises.map(x => ({ kind: 'exercise' as const, key: `x${x.exercise_id}`, time: x.time, title: x.title, detail: `${x.duration_min} phút${x.note ? ` · ${x.note}` : ''}`, status: liveStatus(x.status, x.time, g), raw: x })),
  ].sort((a, b) => a.time.localeCompare(b.time));
}

export default function ElderHome() {
  const { user, signOut } = useApp();
  const [data, setData] = useState<TodayData | null>(null);
  const [now, setNow] = useState(new Date());
  const [setupDone, setSetupDone] = useState<boolean | null>(null);
  const [alarm, setAlarm] = useState<Item[] | null>(null);
  const [askHelp, setAskHelp] = useState(false);
  const [noVoice, setNoVoice] = useState(false);
  const snoozed = useRef<Record<string, number>>({});
  const alarmKey = useRef('');
  const repeat = useRef<ReturnType<typeof setInterval> | null>(null);

  const name = data?.me.name || user?.name || 'Bạn';
  const items = toItems(data);

  const refresh = useCallback(async () => {
    try {
      const d = await api.get<TodayData>('/elder/today');
      setData(d);
      // Đặt lại thông báo cho 3 ngày tới: điện thoại tự nhắc kể cả khi app đã tắt
      const schedule = await api.get<Reminder[]>('/elder/schedule?days=3');
      scheduleReminders(schedule, d.me.name).catch(() => {});
    } catch {}
  }, []);

  useEffect(() => {
    storage.get('elder_setup').then(v => setSetupDone(v === '1'));
    hasVietnameseVoice().then(ok => setNoVoice(!ok));
    const first = setTimeout(refresh, 0);
    const clock = setInterval(() => setNow(new Date()), 10_000);
    const poll = setInterval(refresh, 60_000);
    const app = AppState.addEventListener('change', s => s === 'active' && refresh());
    const received = Notifications.addNotificationReceivedListener(() => refresh());
    const tapped = Notifications.addNotificationResponseReceivedListener(() => refresh());
    return () => {
      clearTimeout(first); clearInterval(clock); clearInterval(poll); app.remove(); received.remove(); tapped.remove();
      if (repeat.current) clearInterval(repeat.current);
      stopSpeaking();
    };
  }, [refresh]);

  // Kiểm tra có việc nào đến giờ không (mỗi khi đồng hồ nhảy hoặc dữ liệu đổi)
  useEffect(() => {
    if (!setupDone) return;
    const t = Date.now();
    const due = items.filter(i => i.status === 'due' && !(snoozed.current[i.key] > t));
    const key = due.map(i => i.key).join(',');
    if (key === alarmKey.current) return;
    alarmKey.current = key;
    if (due.length) openAlarm(due);
    else closeAlarm();
  }, [now, data, setupDone]);

  function alarmText(group: Item[]) {
    const doses = group.filter(i => i.kind === 'dose');
    if (doses.length) {
      return `${name} ơi, đến giờ uống thuốc rồi ạ. ${doses.map(d => `${d.title}, ${(d.raw as Dose).dosage || ''}`).join('. ')}. Uống xong, ${name} bấm nút màu xanh nhé.`;
    }
    const x = group[0];
    return `${name} ơi, đến giờ ${x.title.toLowerCase()} rồi ạ, ${(x.raw as ExerciseItem).duration_min} phút. Đi tập xong, ${name} bấm nút màu xanh nhé.`;
  }

  function ring(group: Item[]) {
    Vibration.vibrate([0, 500, 300, 500, 300, 500]);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning).catch(() => {});
    speak(alarmText(group));
  }

  function openAlarm(group: Item[]) {
    setAlarm(group);
    ring(group);
    if (repeat.current) clearInterval(repeat.current);
    repeat.current = setInterval(() => ring(group), REPEAT_MS);
  }

  function closeAlarm() {
    if (repeat.current) clearInterval(repeat.current);
    repeat.current = null;
    Vibration.cancel();
    stopSpeaking();
    setAlarm(null);
  }

  async function markDone(list: Item[]) {
    for (const i of list) {
      if (i.kind === 'dose') await api.post('/elder/doses', { med_id: (i.raw as Dose).med_id, time: i.time, status: 'taken' });
      else await api.post('/elder/exercises', { exercise_id: (i.raw as ExerciseItem).exercise_id, status: 'done' });
    }
  }

  async function confirmAlarm() {
    const group = alarm!;
    closeAlarm();
    try {
      await markDone(group);
      speak(group.some(i => i.kind === 'dose') ? `Cảm ơn ${name}. Đã ghi nhận ${name} uống thuốc rồi ạ.` : `Giỏi quá. Chúc ${name} tập vui khỏe ạ.`);
    } catch (e: any) { Alert.alert('Chưa gửi được', e.message); }
    alarmKey.current = '';
    refresh();
  }

  function snooze() {
    const until = Date.now() + SNOOZE_MIN * 60000;
    alarm!.forEach(i => { snoozed.current[i.key] = until; });
    closeAlarm();
    speak(`Vâng, ${SNOOZE_MIN} phút nữa tôi sẽ nhắc lại.`);
  }

  async function finishSetup() {
    await setupNotifications().catch(() => false);
    await storage.set('elder_setup', '1');
    setSetupDone(true);
    speak(`Chào ${name}. Từ nay đến giờ uống thuốc hay tập thể dục, tôi sẽ nhắc ${name}.`);
    refresh();
  }

  async function sendHelp() {
    setAskHelp(false);
    try {
      await api.post('/elder/alert', { kind: 'help' });
      speak('Đã báo cho con rồi ạ. Con sẽ gọi lại ngay.');
    } catch (e: any) { Alert.alert('Chưa gửi được', e.message); }
  }

  if (!user) return <Redirect href="/login" />;
  if (setupDone === null || !data) return <Loading />;

  if (!setupDone) {
    return (
      <SafeAreaView style={[st.full, { backgroundColor: C.bg }]}>
        <View style={st.bigIcon}><Ionicons name="notifications" size={64} color={C.primary} /></View>
        <T size={30} weight="black" center>Cho phép nhắc giờ</T>
        <T size={21} color={C.muted} center>Bấm nút bên dưới, rồi chọn <T size={21} weight="bold">“Cho phép”</T> khi điện thoại hỏi.</T>
        <BigButton label="Đồng ý" icon="checkmark" color={C.ok} onPress={finishSetup} />
      </SafeAreaView>
    );
  }

  const next = items.find(i => i.status === 'due' || i.status === 'upcoming');
  const missed = items.filter(i => i.status === 'missed');
  const contact = data.contacts.find(c => c.phone);
  const nextGroup = next ? items.filter(i => i.time === next.time && i.kind === next.kind && (i.status === 'due' || i.status === 'upcoming')) : [];
  const heroColor = !items.length || (!next && !missed.length) ? C.ok : next ? (next.kind === 'dose' ? C.primary : C.navy) : C.danger;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
      <ScrollView contentContainerStyle={{ padding: 20, gap: 18, paddingBottom: 40 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <View style={{ flex: 1 }}>
            <T size={20} color={C.muted}>{greeting()},</T>
            <T size={32} weight="black">{name}</T>
            <T size={18} color={C.muted}>{WEEKDAY_FULL[now.getDay()]}, {now.getDate()}/{now.getMonth() + 1}</T>
          </View>
          <T size={46} weight="black" color={C.navy}>{now.toTimeString().slice(0, 5)}</T>
        </View>

        <View style={[st.hero, { backgroundColor: heroColor }]}>
          {next ? (
            <>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                <Ionicons name={next.kind === 'dose' ? 'medical' : 'walk'} size={30} color="#fff" />
                <T size={20} color="#fff" weight="semi">{next.status === 'due' ? 'Đến giờ rồi' : next.kind === 'dose' ? 'Lần uống thuốc tới' : 'Giờ tập tới'}</T>
              </View>
              <T size={56} weight="black" color="#fff">{next.time}</T>
              {nextGroup.map(i => <T key={i.key} size={23} weight="bold" color="#fff">{i.title}{(i.raw as Dose).dosage ? ` – ${(i.raw as Dose).dosage}` : ''}</T>)}
            </>
          ) : missed.length ? (
            <>
              <T size={20} color="#fff" weight="semi">Hôm nay</T>
              <T size={30} weight="black" color="#fff">Còn {missed.length} việc chưa làm</T>
              <T size={19} color="#fff">Nếu đã làm rồi, bấm nút “Tôi đã làm” bên dưới</T>
            </>
          ) : (
            <>
              <Ionicons name="happy" size={46} color="#fff" />
              <T size={30} weight="black" color="#fff">{items.length ? 'Hôm nay đã xong hết!' : 'Hôm nay không có lịch'}</T>
            </>
          )}
        </View>

        <T size={24} weight="bold">Việc hôm nay</T>
        {items.map(i => <ItemRow key={i.key} item={i} onDone={async () => { await markDone([i]); refresh(); }} />)}
        {!items.length && <T size={19} color={C.muted}>Chưa có lịch nào.</T>}

        <View style={{ gap: 14, marginTop: 6 }}>
          {contact && <BigButton label={`Gọi cho ${contact.name}`} icon="call" color={C.navy} onPress={() => Linking.openURL(`tel:${contact.phone}`)} />}
          <BigButton label="Tôi thấy không khỏe" icon="hand-left" color={C.danger} outline onPress={() => { setAskHelp(true); speak('Bấm nút màu đỏ để báo cho con biết.'); }} />
        </View>

        {noVoice && (
          <View style={st.warn}>
            <T size={16} color="#6B4106">Điện thoại chưa có giọng đọc tiếng Việt. Nhờ con vào Cài đặt → Ngôn ngữ → Chuyển văn bản thành giọng nói, tải giọng Tiếng Việt.</T>
          </View>
        )}
        <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 24, marginTop: 8 }}>
          <Pressable onPress={() => speak(`${name} ơi, đây là giọng nhắc uống thuốc.`)}><T size={16} color={C.muted} style={{ textDecorationLine: 'underline' }}>Nghe thử giọng nhắc</T></Pressable>
          <Pressable onPress={() => Alert.alert('Đăng xuất?', 'Sẽ cần nhập lại mã của con.', [
            { text: 'Không', style: 'cancel' },
            { text: 'Đăng xuất', style: 'destructive', onPress: async () => { await signOut(); router.replace('/login'); } },
          ])}><T size={16} color={C.muted} style={{ textDecorationLine: 'underline' }}>Đăng xuất</T></Pressable>
        </View>
      </ScrollView>

      <AlarmModal group={alarm} name={name} onConfirm={confirmAlarm} onSnooze={snooze} />

      <Modal visible={askHelp} animationType="fade" onRequestClose={() => setAskHelp(false)}>
        <SafeAreaView style={[st.full, { backgroundColor: C.bg }]}>
          <View style={[st.bigIcon, { backgroundColor: C.dangerSoft }]}><Ionicons name="hand-left" size={60} color={C.danger} /></View>
          <T size={30} weight="black" center>Báo cho con biết bạn đang không khỏe?</T>
          <BigButton label="Có, báo cho con" icon="send" color={C.danger} onPress={sendHelp} />
          <BigButton label="Không" color={C.muted} outline onPress={() => setAskHelp(false)} />
        </SafeAreaView>
      </Modal>
    </SafeAreaView>
  );
}

function ItemRow({ item, onDone }: { item: Item; onDone: () => void }) {
  const isDose = item.kind === 'dose';
  const done = ['taken', 'skipped', 'done'].includes(item.status);
  const badge = done ? { bg: C.ok, icon: 'checkmark' } : item.status === 'missed' ? { bg: C.danger, icon: 'alert' } : item.status === 'due' ? { bg: C.warn, icon: 'alarm' } : null;
  return (
    <View style={[st.item, done && { backgroundColor: C.okSoft, borderColor: '#BFE3CF' }, item.status === 'due' && { borderColor: C.warn, backgroundColor: C.warnSoft }]}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        <Ionicons name={isDose ? 'medical' : 'walk'} size={26} color={isDose ? C.primary : C.navy} />
        <T size={30} weight="black" style={{ flex: 1 }}>{item.time}</T>
        <View style={[st.badge, { backgroundColor: badge?.bg || C.grey }]}>
          {badge ? <Ionicons name={badge.icon as any} size={30} color="#fff" /> : <Ionicons name="time-outline" size={26} color={C.muted} />}
        </View>
      </View>
      <View>
        <T size={23} weight="bold">{item.title}</T>
        {item.detail ? <T size={18} color={C.muted}>{item.detail}</T> : null}
      </View>
      {(item.status === 'missed' || item.status === 'due') && (
        <Pressable onPress={onDone} style={st.lateBtn}>
          <T size={18} weight="bold" color={C.ok}>{isDose ? 'Tôi đã uống' : 'Tôi đã tập'}</T>
        </Pressable>
      )}
    </View>
  );
}

function AlarmModal({ group, name, onConfirm, onSnooze }: { group: Item[] | null; name: string; onConfirm: () => void; onSnooze: () => void }) {
  const [scale] = useState(() => new Animated.Value(1));
  useEffect(() => {
    if (!group) return;
    const loop = Animated.loop(Animated.sequence([
      Animated.timing(scale, { toValue: 1.15, duration: 500, easing: Easing.out(Easing.quad), useNativeDriver: true }),
      Animated.timing(scale, { toValue: 1, duration: 500, easing: Easing.in(Easing.quad), useNativeDriver: true }),
    ]));
    loop.start();
    return () => loop.stop();
  }, [group, scale]);
  if (!group) return null;
  const isDose = group.some(i => i.kind === 'dose');
  const bg = isDose ? C.primary : C.navy;
  return (
    <Modal visible animationType="slide" onRequestClose={onSnooze}>
      <SafeAreaView style={[st.full, { backgroundColor: bg }]}>
        <Animated.View style={[st.alarmIcon, { transform: [{ scale }] }]}>
          <Ionicons name={isDose ? 'medical' : 'walk'} size={70} color={bg} />
        </Animated.View>
        <T size={34} weight="black" color="#fff" center>{name} ơi,{'\n'}{isDose ? 'đến giờ uống thuốc' : 'đến giờ tập thể dục'}</T>
        <View style={{ alignSelf: 'stretch', gap: 10 }}>
          {group.map(i => (
            <View key={i.key} style={st.alarmItem}>
              <T size={26} weight="bold">{i.title}</T>
              {i.detail ? <T size={19} color={C.muted}>{i.detail}</T> : null}
            </View>
          ))}
        </View>
        <Pressable onPress={onConfirm} style={({ pressed }) => [st.confirm, pressed && { transform: [{ scale: 0.98 }] }]}>
          <Ionicons name="checkmark-circle" size={44} color={C.ok} />
          <T size={30} weight="black" color={C.ok}>{isDose ? 'ĐÃ UỐNG RỒI' : 'TÔI ĐI TẬP ĐÂY'}</T>
        </Pressable>
        <Pressable onPress={onSnooze} style={st.snooze}>
          <T size={20} weight="semi" color="#fff">Nhắc lại sau {SNOOZE_MIN} phút</T>
        </Pressable>
      </SafeAreaView>
    </Modal>
  );
}

function BigButton({ label, icon, color, outline, onPress }: { label: string; icon?: any; color: string; outline?: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [st.bigBtn, outline ? { borderColor: color, backgroundColor: C.surface } : { backgroundColor: color, borderColor: color }, pressed && { opacity: 0.9 }]}
    >
      {icon && <Ionicons name={icon} size={30} color={outline ? color : '#fff'} />}
      <T size={24} weight="bold" color={outline ? color : '#fff'}>{label}</T>
    </Pressable>
  );
}

const st = StyleSheet.create({
  full: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 22 },
  bigIcon: { width: 120, height: 120, borderRadius: 40, backgroundColor: C.primarySoft, alignItems: 'center', justifyContent: 'center' },
  hero: { borderRadius: R.xl, padding: 24, gap: 4 },
  item: { backgroundColor: C.surface, borderRadius: R.lg, padding: 16, borderWidth: 2, borderColor: C.line, gap: 12 },
  badge: { width: 54, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center' },
  lateBtn: { alignSelf: 'flex-start', borderWidth: 2, borderColor: C.ok, borderRadius: R.md, paddingHorizontal: 16, paddingVertical: 8, backgroundColor: C.surface },
  bigBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, paddingVertical: 22, borderRadius: R.xl, borderWidth: 3, alignSelf: 'stretch' },
  warn: { backgroundColor: C.warnSoft, borderRadius: R.md, padding: 14 },
  alarmIcon: { width: 140, height: 140, borderRadius: 70, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center' },
  alarmItem: { backgroundColor: '#fff', borderRadius: R.lg, padding: 16 },
  confirm: { alignSelf: 'stretch', backgroundColor: '#fff', borderRadius: R.xl, paddingVertical: 28, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12 },
  snooze: { paddingVertical: 14, paddingHorizontal: 24, borderRadius: R.xl, borderWidth: 2, borderColor: 'rgba(255,255,255,0.6)' },
});
