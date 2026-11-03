import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Image, Pressable, StyleSheet, Switch, View } from 'react-native';
import { TimeEditor } from '@/components/time-editor';
import { Button, Card, ErrorText, Field, Screen, T } from '@/components/ui';
import { api, type OcrItem } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { addDays, dayLabel, today } from '@/lib/format';
import { C, R } from '@/lib/theme';

type Row = OcrItem & { on: boolean; daysText: string };

// Quét toa thuốc: chụp ảnh -> server đọc chữ (Google Vision) -> tách thuốc -> người con duyệt -> tạo lịch nhắc
export default function OcrScreen() {
  const { date } = useLocalSearchParams<{ date?: string }>();
  const start = date || today();
  const { elder } = useApp();
  const [image, setImage] = useState<string | null>(null);
  const [text, setText] = useState('');
  const [showText, setShowText] = useState(false);
  const [rows, setRows] = useState<Row[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const toRows = (items: OcrItem[]) => items.map(i => ({ ...i, on: true, daysText: i.days ? String(i.days) : '' }));

  async function pick(camera: boolean) {
    setError('');
    const perm = camera ? await ImagePicker.requestCameraPermissionsAsync() : await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return setError('Bạn cần cho phép truy cập ' + (camera ? 'máy ảnh' : 'thư viện ảnh'));
    const opts: ImagePicker.ImagePickerOptions = { mediaTypes: ['images'], quality: 0.6, base64: true, allowsEditing: true };
    const res = camera ? await ImagePicker.launchCameraAsync(opts) : await ImagePicker.launchImageLibraryAsync(opts);
    if (res.canceled || !res.assets[0].base64) return;
    setImage(res.assets[0].uri);
    setBusy(true);
    setRows(null);
    try {
      const out = await api.post<{ text: string; items: OcrItem[] }>('/ocr/image', { image_base64: res.assets[0].base64 });
      setText(out.text);
      setRows(toRows(out.items));
      if (!out.items.length) setError('Đọc được chữ nhưng không nhận ra thuốc nào. Hãy kiểm tra và sửa văn bản bên dưới.');
    } catch (e: any) {
      setError(e.message);
      setShowText(true);
    } finally {
      setBusy(false);
    }
  }

  async function parseText() {
    setError('');
    setBusy(true);
    try {
      const out = await api.post<{ items: OcrItem[] }>('/ocr/parse', { text });
      setRows(toRows(out.items));
      if (!out.items.length) setError('Không nhận ra thuốc nào. Mỗi thuốc nên nằm trên một dòng, có tên và hàm lượng (vd: Amlodipin 5mg).');
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  const update = (i: number, patch: Partial<Row>) => setRows(r => r!.map((x, j) => (j === i ? { ...x, ...patch } : x)));

  async function createAll() {
    setSaving(true);
    setError('');
    try {
      for (const r of rows!.filter(x => x.on)) {
        const n = Number(r.daysText);
        await api.post(`/elders/${elder!.id}/medications`, {
          name: r.name, dosage: r.dosage, note: r.note, times: r.times,
          start_date: start, end_date: n > 0 ? addDays(start, n - 1) : null,
        });
      }
      router.back();
    } catch (e: any) { setError(e.message); } finally { setSaving(false); }
  }

  const selected = rows?.filter(r => r.on && r.name && r.times.length).length ?? 0;

  return (
    <Screen edges={['bottom']}>
      <T color={C.muted}>Tạo lịch nhắc cho {elder?.name}, bắt đầu {dayLabel(start).toLowerCase()}</T>

      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Source icon="camera" label="Chụp toa thuốc" onPress={() => pick(true)} primary />
        <Source icon="images" label="Chọn ảnh có sẵn" onPress={() => pick(false)} />
      </View>

      {image && <Image source={{ uri: image }} style={st.preview} resizeMode="cover" />}
      {busy && (
        <Card style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
          <ActivityIndicator color={C.primary} />
          <T>Đang đọc toa thuốc…</T>
        </Card>
      )}
      <ErrorText text={error} />

      <Pressable onPress={() => setShowText(v => !v)} style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
        <Ionicons name={showText ? 'chevron-down' : 'chevron-forward'} size={16} color={C.muted} />
        <T size={13} weight="semi" color={C.muted}>{text ? 'Xem / sửa chữ đã đọc được' : 'Hoặc gõ / dán nội dung toa thuốc'}</T>
      </Pressable>
      {showText && (
        <Card style={{ gap: 10 }}>
          <Field label="Nội dung toa" value={text} onChangeText={setText} multiline
            placeholder={'1. Amlodipin 5mg  30 viên\n   Ngày uống 1 lần, mỗi lần 1 viên, sáng sau ăn'} />
          <Button title="Tách danh sách thuốc" kind="ghost" size="sm" onPress={parseText} disabled={!text.trim()} />
        </Card>
      )}

      {rows && rows.length > 0 && (
        <>
          <T size={17} weight="bold">Kiểm tra lại trước khi tạo lịch</T>
          <T size={12.5} color={C.muted}>Máy đọc có thể sai. Hãy so với toa thuốc và sửa nếu cần.</T>
          {rows.map((r, i) => (
            <Card key={i} style={[{ gap: 12 }, !r.on && { opacity: 0.55 }]}>
              <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                <T weight="bold" color={C.primaryDark}>Thuốc {i + 1}</T>
                <Switch value={r.on} onValueChange={v => update(i, { on: v })} trackColor={{ true: C.primary }} />
              </View>
              <Field label="Tên thuốc" value={r.name} onChangeText={v => update(i, { name: v })} />
              <View style={{ flexDirection: 'row', gap: 10 }}>
                <View style={{ flex: 1 }}><Field label="Liều mỗi lần" value={r.dosage} onChangeText={v => update(i, { dosage: v })} /></View>
                <View style={{ width: 110 }}><Field label="Số ngày" value={r.daysText} onChangeText={v => update(i, { daysText: v.replace(/\D/g, '') })} keyboardType="number-pad" placeholder="Lâu dài" /></View>
              </View>
              <TimeEditor value={r.times} onChange={v => update(i, { times: v })} />
              <Field label="Ghi chú" value={r.note} onChangeText={v => update(i, { note: v })} />
            </Card>
          ))}
          <Button title={`Tạo ${selected} lịch nhắc`} size="lg" icon="checkmark-circle" onPress={createAll} loading={saving} disabled={!selected} />
        </>
      )}
    </Screen>
  );
}

function Source({ icon, label, onPress, primary }: any) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [st.source, primary && { backgroundColor: C.primary, borderColor: C.primary }, pressed && { opacity: 0.85 }]}>
      <Ionicons name={icon} size={28} color={primary ? '#fff' : C.primary} />
      <T size={13.5} weight="semi" color={primary ? '#fff' : C.ink} center>{label}</T>
    </Pressable>
  );
}

const st = StyleSheet.create({
  source: { flex: 1, alignItems: 'center', gap: 8, paddingVertical: 20, borderRadius: R.lg, backgroundColor: C.surface, borderWidth: 1.5, borderColor: C.line },
  preview: { width: '100%', height: 180, borderRadius: R.lg, backgroundColor: C.grey },
});
