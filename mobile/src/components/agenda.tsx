import { Ionicons } from '@expo/vector-icons';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { C, R, STATUS } from '@/lib/theme';
import type { Dose, Elder, ExerciseItem } from '@/lib/api';
import { timeOf } from '@/lib/format';
import { Chip, StatusPill, T } from './ui';

export type AgendaEntry =
  | { kind: 'dose'; time: string; item: Dose }
  | { kind: 'exercise'; time: string; item: ExerciseItem };

export function mergeAgenda(doses: Dose[], exercises: ExerciseItem[]): AgendaEntry[] {
  return [
    ...doses.map(d => ({ kind: 'dose' as const, time: d.time, item: d })),
    ...exercises.map(x => ({ kind: 'exercise' as const, time: x.time, item: x })),
  ].sort((a, b) => a.time.localeCompare(b.time));
}

// Một dòng trong lịch: giờ - biểu tượng - tên - trạng thái - nút đánh dấu
export function AgendaRow({ entry, onToggle }: { entry: AgendaEntry; onToggle?: (e: AgendaEntry) => void }) {
  const isDose = entry.kind === 'dose';
  const it = entry.item as any;
  const st = STATUS[it.status as keyof typeof STATUS];
  const finished = ['taken', 'skipped', 'done'].includes(it.status);
  const canMark = it.status !== 'upcoming' || finished;
  let who = '';
  if (isDose && it.logged_by && it.logged_at) {
    who = it.logged_by.role === 'elder' ? `Tự xác nhận lúc ${timeOf(it.logged_at)}` : `${it.logged_by.name} đánh dấu`;
  } else if (!isDose && it.logged_at) {
    who = `Hoàn thành lúc ${timeOf(it.logged_at)}`;
  }
  return (
    <View style={s.row}>
      <T size={15} weight="bold" numberOfLines={1} style={{ width: 52 }}>{entry.time}</T>
      <View style={[s.rail, { backgroundColor: st.color }]} />
      <View style={[s.icon, { backgroundColor: isDose ? C.primarySoft : C.navySoft }]}>
        <Ionicons name={isDose ? 'medical' : 'walk'} size={18} color={isDose ? C.primary : C.navy} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <T weight="semi" numberOfLines={1}>{isDose ? it.name : it.title}</T>
        <T size={12.5} color={C.muted} numberOfLines={1}>
          {[isDose ? it.dosage : `${it.duration_min} phút`, who || it.note].filter(Boolean).join(' · ')}
        </T>
        <StatusPill status={it.status} />
      </View>
      {onToggle && canMark && (
        <Pressable onPress={() => onToggle(entry)} hitSlop={8} style={[s.check, finished && { backgroundColor: C.ok, borderColor: C.ok }]}>
          <Ionicons name="checkmark" size={18} color={finished ? '#fff' : C.muted} />
        </Pressable>
      )}
    </View>
  );
}

export function ElderSwitcher({ elders, current, onSelect }: { elders: Elder[]; current: Elder | null; onSelect: (id: number) => void }) {
  if (elders.length < 2) return null;
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
      {elders.map(e => (
        <Chip key={e.id} label={e.name} active={e.id === current?.id} onPress={() => onSelect(e.id)} color={C.navy} />
      ))}
    </ScrollView>
  );
}

const s = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 10 },
  rail: { width: 3, alignSelf: 'stretch', borderRadius: 2 },
  icon: { width: 36, height: 36, borderRadius: R.sm, alignItems: 'center', justifyContent: 'center' },
  check: { width: 34, height: 34, borderRadius: 17, borderWidth: 2, borderColor: C.line, alignItems: 'center', justifyContent: 'center' },
});
