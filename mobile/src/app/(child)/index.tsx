import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, Linking, StyleSheet, View } from 'react-native';
import { AgendaRow, ElderSwitcher, mergeAgenda, type AgendaEntry } from '@/components/agenda';
import { Button, Card, Empty, ErrorText, Screen, SectionHeader, T } from '@/components/ui';
import { toggleEntry } from '@/lib/actions';
import { api, type CalendarDay } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { dayLabel, greeting, shortDate, timeOf, today } from '@/lib/format';
import { C, R } from '@/lib/theme';

export default function ChildHome() {
  const { user, elders, elder, selectElder, reloadElders } = useApp();
  const [day, setDay] = useState<CalendarDay | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const list = await reloadElders();
      const current = list.find(e => e.id === elder?.id) || list[0];
      if (current) {
        const t = today();
        const [d] = await api.get<CalendarDay[]>(`/elders/${current.id}/calendar?from=${t}&to=${t}`);
        setDay(d);
      } else setDay(null);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [reloadElders, elder?.id]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  async function onToggle(e: AgendaEntry) {
    try { await toggleEntry(elder!.id, e); load(); } catch (ex: any) { Alert.alert('Lỗi', ex.message); }
  }

  if (!loading && !elders.length && !error) {
    return (
      <Screen>
        <T size={26} weight="black">{greeting()}, {user?.name}</T>
        <Card style={{ gap: 12, alignItems: 'center', padding: 24 }}>
          <Ionicons name="person-add-outline" size={40} color={C.primary} />
          <T size={18} weight="bold" center>Thêm hồ sơ bố / mẹ</T>
          <T color={C.muted} center>Ứng dụng sẽ tạo một mã 6 số để cài trên điện thoại của bố mẹ.</T>
          <Button title="Thêm bố / mẹ" icon="add" onPress={() => router.push('/elder-form')} />
        </Card>
      </Screen>
    );
  }

  const s = day?.summary;
  const agenda = day ? mergeAgenda(day.doses, day.exercises) : [];
  const exDone = day?.exercises.filter(x => x.status === 'done').length ?? 0;
  const pct = s && s.total ? Math.round((100 * s.taken) / s.total) : 0;
  const bp = elder?.latest_health?.bp;

  return (
    <Screen refreshing={loading} onRefresh={load}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
        <View>
          <T size={14} color={C.muted}>{greeting()},</T>
          <T size={24} weight="black">{user?.name}</T>
        </View>
        {elder?.phone ? <Button title="Gọi" icon="call" kind="soft" size="sm" onPress={() => Linking.openURL(`tel:${elder.phone}`)} /> : null}
      </View>

      <ElderSwitcher elders={elders} current={elder} onSelect={id => { selectElder(id); setTimeout(load, 0); }} />
      <ErrorText text={error} />

      {elder?.alerts?.map(a => (
        <Card key={a.id} style={st.alert}>
          <Ionicons name="warning" size={24} color={C.danger} />
          <View style={{ flex: 1 }}>
            <T weight="bold" color="#8A2323">{elder.name} báo đang không khỏe</T>
            <T size={13} color="#8A2323">Lúc {timeOf(a.created_at)} ngày {shortDate(a.created_at)}</T>
          </View>
          <Button title="Đã xử lý" kind="ghost" size="sm" onPress={async () => { await api.post(`/alerts/${a.id}/resolve`); load(); }} />
        </Card>
      ))}

      {elder && (
        <View style={st.hero}>
          <T size={14} color="#C9D2EC">{dayLabel(today())}</T>
          <T size={22} weight="bold" color="#fff">{elder.name}</T>
          <View style={st.progressTrack}><View style={[st.progressFill, { width: `${pct}%` }]} /></View>
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <Stat label="Đã uống" value={`${s?.taken ?? 0}/${s?.total ?? 0}`} />
            <Stat label="Bị quên" value={String(s?.missed ?? 0)} warn={!!s?.missed} />
            <Stat label="Tập luyện" value={`${exDone}/${day?.exercises.length ?? 0}`} />
            <Stat label="Huyết áp" value={bp ? `${Math.round(bp.value)}/${Math.round(bp.value2 ?? 0)}` : '—'} />
          </View>
        </View>
      )}

      <SectionHeader title="Lịch hôm nay" action={<Button title="Mở lịch" kind="ghost" size="sm" onPress={() => router.push('/(child)/calendar')} />} />
      <Card style={{ paddingVertical: 6 }}>
        {agenda.length ? agenda.map(e => <AgendaRow key={`${e.kind}${(e.item as any).med_id ?? (e.item as any).exercise_id}${e.time}`} entry={e} onToggle={onToggle} />)
          : <Empty icon="calendar-clear-outline" text="Hôm nay chưa có lịch nào" />}
      </Card>

      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Button title="Quét toa" icon="scan" kind="primary" style={{ flex: 1 }} onPress={() => router.push({ pathname: '/ocr', params: { date: today() } })} />
        <Button title="Thêm thuốc" icon="add" kind="ghost" style={{ flex: 1 }} onPress={() => router.push({ pathname: '/med-form', params: { date: today() } })} />
      </View>
    </Screen>
  );
}

function Stat({ label, value, warn }: { label: string; value: string; warn?: boolean }) {
  return (
    <View style={{ flex: 1 }}>
      <T size={17} weight="bold" numberOfLines={1} color={warn ? '#FFB4A8' : '#fff'}>{value}</T>
      <T size={11.5} color="#C9D2EC">{label}</T>
    </View>
  );
}

const st = StyleSheet.create({
  hero: { backgroundColor: C.navy, borderRadius: R.xl, padding: 20, gap: 8 },
  progressTrack: { height: 8, borderRadius: 4, backgroundColor: 'rgba(255,255,255,0.18)', marginVertical: 6, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: C.primary, borderRadius: 4 },
  alert: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: C.dangerSoft },
});
