import { router } from 'expo-router';
import { useState } from 'react';
import { Button, Card, ErrorText, Field, Screen, T } from '@/components/ui';
import { api, type Elder } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { C } from '@/lib/theme';

export default function ElderForm() {
  const { reloadElders, selectElder } = useApp();
  const [f, setF] = useState({ name: '', birth_year: '', phone: '', note: '' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (v: string) => setF(x => ({ ...x, [k]: v }));

  async function save() {
    setBusy(true);
    setError('');
    try {
      const e = await api.post<Elder>('/elders', f);
      await reloadElders();
      selectElder(e.id);
      router.back();
      router.push('/(child)/settings');
    } catch (ex: any) { setError(ex.message); } finally { setBusy(false); }
  }

  return (
    <Screen edges={['bottom']}>
      <T color={C.muted}>Sau khi tạo, bạn sẽ nhận một mã 6 số để cài trên điện thoại của bố / mẹ.</T>
      <Card style={{ gap: 14 }}>
        <Field label="Tên gọi" hint="Giọng nhắc sẽ gọi theo tên này, vd: “Bà Lan”, “Bố”" value={f.name} onChangeText={set('name')} />
        <Field label="Năm sinh" value={f.birth_year} onChangeText={set('birth_year')} keyboardType="number-pad" />
        <Field label="Số điện thoại" value={f.phone} onChangeText={set('phone')} keyboardType="phone-pad" />
        <Field label="Ghi chú sức khỏe" value={f.note} onChangeText={set('note')} placeholder="Bệnh nền, dị ứng thuốc…" multiline />
      </Card>
      <ErrorText text={error} />
      <Button title="Tạo hồ sơ" size="lg" onPress={save} loading={busy} disabled={!f.name} />
    </Screen>
  );
}
