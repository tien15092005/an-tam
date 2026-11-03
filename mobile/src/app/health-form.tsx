import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { Button, Card, Chip, ErrorText, Field, Screen, T } from '@/components/ui';
import { api } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { HEALTH } from '@/lib/health';
import { C } from '@/lib/theme';

export default function HealthForm() {
  const { elder } = useApp();
  const [type, setType] = useState('bp');
  const [value, setValue] = useState('');
  const [value2, setValue2] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const bp = type === 'bp';

  async function save() {
    setBusy(true);
    setError('');
    try {
      await api.post(`/elders/${elder!.id}/health`, {
        type, note,
        value: value.replace(',', '.'),
        value2: bp ? value2.replace(',', '.') : undefined,
      });
      router.back();
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  return (
    <Screen edges={['bottom']}>
      <T color={C.muted}>Cho {elder?.name}</T>
      <Card style={{ gap: 10 }}>
        <T weight="bold">Loại chỉ số</T>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {Object.entries(HEALTH).map(([k, h]) => <Chip key={k} label={h.label} active={type === k} onPress={() => setType(k)} color={C.navy} />)}
        </View>
      </Card>
      <Card style={{ gap: 14 }}>
        <View style={{ flexDirection: 'row', gap: 10 }}>
          <View style={{ flex: 1 }}>
            <Field label={bp ? 'Tâm thu' : `Giá trị (${HEALTH[type].unit})`} value={value} onChangeText={setValue} keyboardType="decimal-pad" />
          </View>
          {bp && <View style={{ flex: 1 }}><Field label="Tâm trương" value={value2} onChangeText={setValue2} keyboardType="decimal-pad" /></View>}
        </View>
        <Field label="Ghi chú" value={note} onChangeText={setNote} placeholder="vd: đo sau khi ngủ dậy" />
      </Card>
      <ErrorText text={error} />
      <Button title="Lưu chỉ số" size="lg" onPress={save} loading={busy} disabled={!value || (bp && !value2)} />
    </Screen>
  );
}
