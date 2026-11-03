import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, View } from 'react-native';
import { AgendaRow, ElderSwitcher, mergeAgenda, type AgendaEntry } from '@/components/agenda';
import { MonthGrid, WeekStrip } from '@/components/calendar';
import { Card, Chip, Empty, ErrorText, Screen, SectionHeader, T } from '@/components/ui';
import { toggleEntry } from '@/lib/actions';
import { api, type CalendarDay, type Exercise, type Medication } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { addDays, dayLabel, fromISO, ISO_DAYS, shortDate, startOfWeek, today } from '@/lib/format';
import { C, R } from '@/lib/theme';

export default function CalendarScreen() {
  const { elders, elder, selectElder } = useApp();
  const [mode, setMode] = useState<'week' | 'month'>('week');
  const [selected, setSelected] = useState(today());
  const [days, setDays] = useState<Record<string, CalendarDay>>({});
  const [meds, setMeds] = useState<Medication[]>([]);
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const weekStart = startOfWeek(selected);
  const monthKey = selected.slice(0, 7);
  const range = useMemo(() => {
    if (mode === 'week') return [weekStart, addDays(weekStart, 6)];
    const first = `${monthKey}-01`;
    const gridStart = addDays(first, -((fromISO(first).getDay() + 6) % 7));
    return [gridStart, addDays(gridStart, 41)];
  }, [mode, weekStart, monthKey]);

  const load = useCallback(async () => {
    if (!elder) return;
    setLoading(true);
    setError('');
    try {
      const [cal, m, x] = await Promise.all([
        api.get<CalendarDay[]>(`/elders/${elder.id}/calendar?from=${range[0]}&to=${range[1]}`),
        api.get<Medication[]>(`/elders/${elder.id}/medications`),
        api.get<Exercise[]>(`/elders/${elder.id}/exercises`),
      ]);
      setDays(Object.fromEntries(cal.map(d => [d.date, d])));
      setMeds(m);
      setExercises(x);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [elder, range]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  async function onToggle(e: AgendaEntry) {
    try { await toggleEntry(elder!.id, e); load(); } catch (ex: any) { Alert.alert('Lỗi', ex.message); }
  }

  if (!elder) return <Screen><Empty icon="calendar-outline" text="Hãy thêm hồ sơ bố / mẹ ở tab Cài đặt trước." /></Screen>;

  const day = days[selected];
  const agenda = day ? mergeAgenda(day.doses, day.exercises) : [];
  const shift = (n: number) => {
    if (mode === 'week') return setSelected(addDays(selected, 7 * n));
    const d = fromISO(`${monthKey}-01`);
    d.setMonth(d.getMonth() + n);
    setSelected(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`);
  };
  const monthTitle = `Tháng ${Number(monthKey.slice(5))}, ${monthKey.slice(0, 4)}`;

  return (
    <Screen refreshing={loading} onRefresh={load}>
      <View style={st.head}>
        <T size={24} weight="black">Lịch của {elder.name}</T>
      </View>
      <ElderSwitcher elders={elders} current={elder} onSelect={selectElder} />

      <View style={st.toolbar}>
        <View style={{ flexDirection: 'row', gap: 6 }}>
          <Chip label="Tuần" active={mode === 'week'} onPress={() => setMode('week')} color={C.navy} />
          <Chip label="Tháng" active={mode === 'month'} onPress={() => setMode('month')} color={C.navy} />
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, flexShrink: 1 }}>
          <Pressable onPress={() => shift(-1)} hitSlop={8} style={st.nav}><Ionicons name="chevron-back" size={18} color={C.ink} /></Pressable>
          <T size={12.5} weight="semi" numberOfLines={1} style={{ flexShrink: 1 }}>{mode === 'week' ? `${shortDate(weekStart)} – ${shortDate(addDays(weekStart, 6))}` : monthTitle}</T>
          <Pressable onPress={() => shift(1)} hitSlop={8} style={st.nav}><Ionicons name="chevron-forward" size={18} color={C.ink} /></Pressable>
        </View>
      </View>

      {mode === 'week'
        ? <WeekStrip start={weekStart} selected={selected} days={days} onSelect={setSelected} />
        : <Card style={{ padding: 10 }}><MonthGrid month={selected} selected={selected} days={days} onSelect={setSelected} /></Card>}

      <ErrorText text={error} />

      <SectionHeader title={dayLabel(selected)} />
      {/* Bấm vào một ngày -> thêm lịch cho đúng ngày đó, kể cả quét toa thuốc */}
      <View style={st.actions}>
        <Action icon="scan" label="Quét toa" color={C.primary} bg={C.primarySoft}
          onPress={() => router.push({ pathname: '/ocr', params: { date: selected } })} />
        <Action icon="medical" label="Thêm thuốc" color={C.primaryDark} bg={C.surface}
          onPress={() => router.push({ pathname: '/med-form', params: { date: selected } })} />
        <Action icon="walk" label="Lịch tập" color={C.navy} bg={C.surface}
          onPress={() => router.push({ pathname: '/exercise-form', params: { date: selected } })} />
      </View>
      <Card style={{ paddingVertical: 6 }}>
        {agenda.length ? agenda.map(e => <AgendaRow key={`${e.kind}${(e.item as any).med_id ?? (e.item as any).exercise_id}${e.time}`} entry={e} onToggle={onToggle} />)
          : <Empty icon="sunny-outline" text="Ngày này chưa có lịch" />}
      </Card>

      <SectionHeader title="Đơn thuốc đang dùng" />
      <Card style={{ paddingVertical: 4 }}>
        {meds.length ? meds.map(m => (
          <Pressable key={m.id} style={st.item} onPress={() => router.push({ pathname: '/med-form', params: { id: String(m.id) } })}>
            <Ionicons name="medical-outline" size={20} color={C.primary} />
            <View style={{ flex: 1 }}>
              <T weight="semi">{m.name} <T size={13} color={C.muted}>{m.dosage}</T></T>
              <T size={12.5} color={C.muted}>
                {m.times.join(' · ')}{m.end_date ? `  ·  đến ${shortDate(m.end_date)}` : '  ·  dùng lâu dài'}
              </T>
            </View>
            <Ionicons name="chevron-forward" size={18} color={C.muted} />
          </Pressable>
        )) : <Empty text="Chưa có thuốc nào" />}
      </Card>

      <SectionHeader title="Lịch tập thể dục" />
      <Card style={{ paddingVertical: 4 }}>
        {exercises.length ? exercises.map(x => (
          <Pressable key={x.id} style={st.item} onPress={() => router.push({ pathname: '/exercise-form', params: { id: String(x.id) } })}>
            <Ionicons name="walk-outline" size={20} color={C.navy} />
            <View style={{ flex: 1 }}>
              <T weight="semi">{x.title} <T size={13} color={C.muted}>{x.duration_min} phút</T></T>
              <T size={12.5} color={C.muted}>
                {x.time} · {x.days.length === 7 ? 'Hằng ngày' : ISO_DAYS.filter(d => x.days.includes(d.v)).map(d => d.label).join(', ')}
              </T>
            </View>
            <Ionicons name="chevron-forward" size={18} color={C.muted} />
          </Pressable>
        )) : <Empty text="Chưa có lịch tập" />}
      </Card>
    </Screen>
  );
}

function Action({ icon, label, color, bg, onPress }: any) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [st.action, { backgroundColor: bg }, pressed && { opacity: 0.8 }]}>
      <Ionicons name={icon} size={22} color={color} />
      <T size={13} weight="semi" color={color}>{label}</T>
    </Pressable>
  );
}

const st = StyleSheet.create({
  head: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  toolbar: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 },
  nav: { width: 32, height: 32, borderRadius: 16, backgroundColor: C.surface, alignItems: 'center', justifyContent: 'center' },
  actions: { flexDirection: 'row', gap: 10 },
  action: { flex: 1, alignItems: 'center', gap: 4, paddingVertical: 14, borderRadius: R.md, borderWidth: 1.5, borderColor: C.line },
  item: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 12 },
});
