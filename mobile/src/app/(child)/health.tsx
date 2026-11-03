import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, Pressable, StyleSheet, View } from 'react-native';
import { ElderSwitcher } from '@/components/agenda';
import { Button, Card, Empty, ErrorText, IconBadge, Screen, SectionHeader, T } from '@/components/ui';
import { api, type HealthRecord } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { HEALTH, healthValue } from '@/lib/health';
import { shortDate, timeOf } from '@/lib/format';
import { C } from '@/lib/theme';

export default function Health() {
  const { elders, elder, selectElder, reloadElders } = useApp();
  const [records, setRecords] = useState<HealthRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    if (!elder) return;
    setLoading(true);
    try {
      setRecords(await api.get<HealthRecord[]>(`/elders/${elder.id}/health?days=60`));
      reloadElders();
      setError('');
    } catch (e: any) { setError(e.message); } finally { setLoading(false); }
  }, [elder?.id]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  if (!elder) return <Screen><Empty text="Hãy thêm hồ sơ bố / mẹ trước." /></Screen>;
  const latest = elder.latest_health || {};

  return (
    <Screen refreshing={loading} onRefresh={load}>
      <T size={24} weight="black">Sức khỏe của {elder.name}</T>
      <ElderSwitcher elders={elders} current={elder} onSelect={selectElder} />
      <ErrorText text={error} />
      <View style={st.grid}>
        {Object.entries(HEALTH).map(([k, h]) => {
          const r = latest[k];
          const bad = r && h.bad(r);
          return (
            <Card key={k} style={[st.tile, bad && { backgroundColor: C.dangerSoft }]}>
              <IconBadge name={h.icon} size={34} color={bad ? C.danger : C.navy} bg={bad ? '#fff' : C.navySoft} />
              <T size={12.5} color={C.muted}>{h.label}</T>
              <T size={20} weight="bold" color={bad ? C.danger : C.ink}>{r ? healthValue(r) : '—'}</T>
              <T size={11.5} color={C.muted}>{r ? `${h.unit} · ${shortDate(r.recorded_at)}` : 'Chưa có'}</T>
            </Card>
          );
        })}
      </View>
      <Button title="Ghi chỉ số mới" icon="add" onPress={() => router.push('/health-form')} />

      <SectionHeader title="Nhật ký 60 ngày" />
      <Card style={{ paddingVertical: 4 }}>
        {records.length ? records.map(r => {
          const h = HEALTH[r.type];
          return (
            <Pressable key={r.id} style={st.row} onLongPress={() => Alert.alert('Xóa bản ghi?', '', [
              { text: 'Hủy', style: 'cancel' },
              { text: 'Xóa', style: 'destructive', onPress: async () => { await api.del(`/health/${r.id}`); load(); } },
            ])}>
              <View style={{ flex: 1 }}>
                <T weight="semi">{h?.label || r.type}</T>
                <T size={12} color={C.muted}>{shortDate(r.recorded_at)} lúc {timeOf(r.recorded_at)}{r.note ? ` · ${r.note}` : ''}</T>
              </View>
              <T weight="bold" color={h?.bad(r) ? C.danger : C.ink}>{healthValue(r)} <T size={12} color={C.muted}>{h?.unit}</T></T>
            </Pressable>
          );
        }) : <Empty icon="pulse-outline" text="Chưa có dữ liệu" />}
      </Card>
      <T size={12} color={C.muted}>Chữ đỏ là ngoài ngưỡng tham khảo thông thường, không thay cho chẩn đoán của bác sĩ. Nhấn giữ một dòng để xóa.</T>
    </Screen>
  );
}

const st = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  tile: { width: '48%', flexGrow: 1, gap: 4, padding: 14 },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 11, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: C.line },
});
