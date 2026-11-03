import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, View } from 'react-native';
import { TimeEditor } from '@/components/time-editor';
import { Button, Card, Chip, ErrorText, Field, Screen, T } from '@/components/ui';
import { api, type Medication } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { addDays, dayLabel, fromISO, toISO, today } from '@/lib/format';
import { C } from '@/lib/theme';

const DURATIONS = [{ label: 'Lâu dài', v: '' }, { label: '5 ngày', v: '5' }, { label: '7 ngày', v: '7' }, { label: '14 ngày', v: '14' }, { label: '30 ngày', v: '30' }];

export default function MedForm() {
  const { id, date } = useLocalSearchParams<{ id?: string; date?: string }>();
  const { elder } = useApp();
  const [name, setName] = useState('');
  const [dosage, setDosage] = useState('');
  const [note, setNote] = useState('');
  const [times, setTimes] = useState<string[]>(['07:30']);
  const [start, setStart] = useState(date || today());
  const [days, setDays] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!id || !elder) return;
    api.get<Medication[]>(`/elders/${elder.id}/medications`).then(list => {
      const m = list.find(x => x.id === Number(id));
      if (!m) return;
      setName(m.name); setDosage(m.dosage); setNote(m.note); setTimes(m.times);
      if (m.start_date) setStart(m.start_date);
      if (m.start_date && m.end_date) {
        setDays(String(Math.round((fromISO(m.end_date).getTime() - fromISO(m.start_date).getTime()) / 86400000) + 1));
      }
    });
  }, [id, elder?.id]);

  async function save() {
    setError('');
    setBusy(true);
    try {
      const n = Number(days);
      const body = {
        name, dosage, note, times,
        start_date: start,
        end_date: days && n > 0 ? addDays(start, n - 1) : null,
      };
      if (id) await api.put(`/medications/${id}`, body);
      else await api.post(`/elders/${elder!.id}/medications`, body);
      router.back();
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  function remove() {
    Alert.alert('Xóa thuốc?', 'Thuốc sẽ không được nhắc nữa. Lịch sử cũ vẫn giữ lại.', [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Xóa', style: 'destructive', onPress: async () => { await api.del(`/medications/${id}`); router.back(); } },
    ]);
  }

  return (
    <Screen edges={['bottom']}>
      <T color={C.muted}>Cho {elder?.name} · bắt đầu {dayLabel(start).toLowerCase()}</T>
      <Card style={{ gap: 14 }}>
        <Field label="Tên thuốc" value={name} onChangeText={setName} placeholder="vd: Amlodipin 5mg" />
        <Field label="Liều mỗi lần" value={dosage} onChangeText={setDosage} placeholder="vd: 1 viên" />
        <Field label="Ghi chú" value={note} onChangeText={setNote} placeholder="vd: uống sau ăn" />
      </Card>
      <Card style={{ gap: 10 }}>
        <T weight="bold">Giờ uống trong ngày</T>
        <TimeEditor value={times} onChange={setTimes} />
      </Card>
      <Card style={{ gap: 10 }}>
        <T weight="bold">Thời gian dùng</T>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {DURATIONS.map(d => <Chip key={d.label} label={d.label} active={days === d.v} onPress={() => setDays(d.v)} />)}
        </View>
        <Field label="Hoặc số ngày" value={days} onChangeText={v => setDays(v.replace(/\D/g, ''))} keyboardType="number-pad" />
        <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center' }}>
          <Button title="−" kind="ghost" size="sm" onPress={() => setStart(addDays(start, -1))} />
          <T weight="semi" style={{ flex: 1 }} center>Bắt đầu: {fromISO(start).getDate()}/{fromISO(start).getMonth() + 1}</T>
          <Button title="+" kind="ghost" size="sm" onPress={() => setStart(addDays(start, 1))} />
        </View>
        {start < toISO(new Date()) && <T size={12} color={C.muted}>Ngày bắt đầu đã qua: các lần trước hôm nay sẽ hiện là “bị quên”.</T>}
      </Card>
      <ErrorText text={error} />
      <Button title={id ? 'Lưu thay đổi' : 'Thêm thuốc'} size="lg" onPress={save} loading={busy} disabled={!name || !times.length} />
      {id && <Button title="Xóa thuốc" kind="danger" onPress={remove} />}
    </Screen>
  );
}
