import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, View } from 'react-native';
import { TimeEditor } from '@/components/time-editor';
import { Button, Card, Chip, ErrorText, Field, Screen, T } from '@/components/ui';
import { api, type Exercise } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { fromISO, ISO_DAYS, today } from '@/lib/format';
import { C } from '@/lib/theme';

const PRESETS = ['Đi bộ', 'Tập dưỡng sinh', 'Thái cực quyền', 'Yoga nhẹ', 'Đạp xe', 'Bơi', 'Tập vật lý trị liệu'];

export default function ExerciseForm() {
  const { id, date } = useLocalSearchParams<{ id?: string; date?: string }>();
  const { elder } = useApp();
  // Mở từ một ngày trong lịch -> chọn sẵn thứ của ngày đó
  const isoDow = date ? ((fromISO(date).getDay() + 6) % 7) + 1 : null;
  const [title, setTitle] = useState('Đi bộ');
  const [time, setTime] = useState<string[]>(['06:00']);
  const [days, setDays] = useState<number[]>(isoDow ? [isoDow] : [1, 2, 3, 4, 5, 6, 7]);
  const [duration, setDuration] = useState('30');
  const [note, setNote] = useState('');
  const [startDate, setStartDate] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!id || !elder) return;
    api.get<Exercise[]>(`/elders/${elder.id}/exercises`).then(list => {
      const x = list.find(e => e.id === Number(id));
      if (!x) return;
      setTitle(x.title); setTime([x.time]); setDays(x.days); setDuration(String(x.duration_min)); setNote(x.note); setStartDate(x.start_date);
    });
  }, [id, elder?.id]);

  const toggleDay = (v: number) => setDays(d => (d.includes(v) ? d.filter(x => x !== v) : [...d, v].sort()));

  async function save() {
    setError('');
    setBusy(true);
    try {
      const body = { title, time: time[0], days, duration_min: Number(duration) || 30, note, start_date: id ? startDate : date && date > today() ? date : null };
      if (id) await api.put(`/exercises/${id}`, body);
      else await api.post(`/elders/${elder!.id}/exercises`, body);
      router.back();
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  function remove() {
    Alert.alert('Xóa lịch tập?', '', [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Xóa', style: 'destructive', onPress: async () => { await api.del(`/exercises/${id}`); router.back(); } },
    ]);
  }

  return (
    <Screen edges={['bottom']}>
      <T color={C.muted}>Lịch tập cho {elder?.name}</T>
      <Card style={{ gap: 12 }}>
        <Field label="Bài tập" value={title} onChangeText={setTitle} />
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {PRESETS.map(p => <Chip key={p} label={p} active={title === p} onPress={() => setTitle(p)} color={C.navy} />)}
        </View>
      </Card>
      <Card style={{ gap: 10 }}>
        <T weight="bold">Giờ tập</T>
        <TimeEditor value={time} onChange={setTime} single />
      </Card>
      <Card style={{ gap: 10 }}>
        <T weight="bold">Các ngày trong tuần</T>
        <View style={{ flexDirection: 'row', gap: 6 }}>
          {ISO_DAYS.map(d => (
            <View key={d.v} style={{ flex: 1 }}>
              <Chip label={d.label} active={days.includes(d.v)} onPress={() => toggleDay(d.v)} color={C.navy} />
            </View>
          ))}
        </View>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Chip label="Hằng ngày" active={days.length === 7} onPress={() => setDays([1, 2, 3, 4, 5, 6, 7])} />
          <Chip label="T2 · T4 · T6" active={days.join() === '1,3,5'} onPress={() => setDays([1, 3, 5])} />
          <Chip label="T3 · T5 · T7" active={days.join() === '2,4,6'} onPress={() => setDays([2, 4, 6])} />
        </View>
      </Card>
      <Card style={{ gap: 12 }}>
        <Field label="Thời lượng (phút)" value={duration} onChangeText={v => setDuration(v.replace(/\D/g, ''))} keyboardType="number-pad" />
        <Field label="Ghi chú" value={note} onChangeText={setNote} placeholder="vd: đi chậm, mang theo nước" />
      </Card>
      <ErrorText text={error} />
      <Button title={id ? 'Lưu thay đổi' : 'Thêm lịch tập'} kind="navy" size="lg" onPress={save} loading={busy} disabled={!title || !time.length || !days.length} />
      {id && <Button title="Xóa lịch tập" kind="danger" onPress={remove} />}
    </Screen>
  );
}
