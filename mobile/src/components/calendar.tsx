import { Pressable, StyleSheet, View } from 'react-native';
import { C, R } from '@/lib/theme';
import type { CalendarDay } from '@/lib/api';
import { addDays, fromISO, today, WEEKDAYS } from '@/lib/format';
import { T } from './ui';

// Màu chấm dưới mỗi ngày: đỏ = có lần quên, xanh = uống đủ, cam = có lịch sắp tới
function dotColor(day?: CalendarDay) {
  if (!day) return null;
  const s = day.summary;
  if (s.missed) return C.danger;
  if (s.total && s.taken + s.skipped === s.total) return C.ok;
  if (s.total || day.exercises.length) return C.warn;
  return null;
}

export function WeekStrip({ start, selected, days, onSelect }: {
  start: string; selected: string; days: Record<string, CalendarDay>; onSelect: (d: string) => void;
}) {
  const t = today();
  return (
    <View style={s.week}>
      {Array.from({ length: 7 }, (_, i) => addDays(start, i)).map(d => {
        const on = d === selected;
        const dot = dotColor(days[d]);
        return (
          <Pressable key={d} onPress={() => onSelect(d)} style={[s.wday, on && s.wdayOn]}>
            <T size={12} weight="semi" color={on ? '#fff' : C.muted}>{WEEKDAYS[fromISO(d).getDay()]}</T>
            <T size={19} weight="bold" color={on ? '#fff' : d === t ? C.primary : C.ink}>{fromISO(d).getDate()}</T>
            <View style={[s.dot, { backgroundColor: dot ? (on ? '#fff' : dot) : 'transparent' }]} />
          </Pressable>
        );
      })}
    </View>
  );
}

export function MonthGrid({ month, selected, days, onSelect }: {
  month: string; selected: string; days: Record<string, CalendarDay>; onSelect: (d: string) => void;
}) {
  const first = fromISO(month.slice(0, 7) + '-01');
  const offset = (first.getDay() + 6) % 7; // tuần bắt đầu từ Thứ 2
  const gridStart = addDays(month.slice(0, 7) + '-01', -offset);
  const t = today();
  return (
    <View>
      <View style={{ flexDirection: 'row' }}>
        {['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map(w => (
          <T key={w} size={12} weight="semi" color={C.muted} center style={{ flex: 1 }}>{w}</T>
        ))}
      </View>
      {Array.from({ length: 6 }, (_, row) => (
        <View key={row} style={{ flexDirection: 'row' }}>
          {Array.from({ length: 7 }, (_, col) => {
            const d = addDays(gridStart, row * 7 + col);
            const inMonth = fromISO(d).getMonth() === first.getMonth();
            const on = d === selected;
            const dot = dotColor(days[d]);
            return (
              <Pressable key={d} onPress={() => onSelect(d)} style={[s.mday, on && s.mdayOn]}>
                <T size={15} weight={d === t || on ? 'bold' : 'medium'} color={on ? '#fff' : !inMonth ? '#C9C1B6' : d === t ? C.primary : C.ink}>
                  {fromISO(d).getDate()}
                </T>
                <View style={[s.dot, { backgroundColor: dot && inMonth ? (on ? '#fff' : dot) : 'transparent' }]} />
              </Pressable>
            );
          })}
        </View>
      ))}
    </View>
  );
}

const s = StyleSheet.create({
  week: { flexDirection: 'row', gap: 5 },
  wday: { flex: 1, minWidth: 0, alignItems: 'center', paddingVertical: 10, borderRadius: R.md, backgroundColor: C.surface, gap: 2 },
  wdayOn: { backgroundColor: C.navy },
  mday: { flex: 1, alignItems: 'center', paddingVertical: 8, borderRadius: R.sm, gap: 2 },
  mdayOn: { backgroundColor: C.navy },
  dot: { width: 6, height: 6, borderRadius: 3 },
});
