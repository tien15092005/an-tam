import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { normalizeTime } from '@/lib/format';
import { C, F, R } from '@/lib/theme';
import { T } from './ui';

const PRESETS = [
  { label: 'Sáng', t: '07:30' }, { label: 'Trưa', t: '11:30' },
  { label: 'Chiều', t: '16:30' }, { label: 'Tối', t: '20:00' },
];

// Chọn nhiều giờ uống: bấm buổi có sẵn hoặc gõ giờ (vd 7:30, 1930)
export function TimeEditor({ value, onChange, single }: { value: string[]; onChange: (v: string[]) => void; single?: boolean }) {
  const [draft, setDraft] = useState('');
  const add = (t: string | null) => {
    if (!t) return;
    onChange(single ? [t] : [...new Set([...value, t])].sort());
    setDraft('');
  };
  return (
    <View style={{ gap: 10 }}>
      <View style={st.wrap}>
        {value.map(t => (
          <Pressable key={t} onPress={() => onChange(value.filter(x => x !== t))} style={st.time}>
            <T weight="bold" color={C.primaryDark}>{t}</T>
            {!single && <Ionicons name="close" size={14} color={C.primaryDark} />}
          </Pressable>
        ))}
        {!value.length && <T size={13} color={C.muted}>Chưa chọn giờ</T>}
      </View>
      <View style={st.wrap}>
        {PRESETS.map(p => (
          <Pressable key={p.t} onPress={() => add(p.t)} style={[st.preset, value.includes(p.t) && { borderColor: C.primary }]}>
            <T size={13} weight="semi">{p.label}</T>
            <T size={11} color={C.muted}>{p.t}</T>
          </Pressable>
        ))}
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <TextInput
          value={draft}
          onChangeText={setDraft}
          placeholder="Giờ khác, vd 9:15"
          placeholderTextColor="#A8A39B"
          keyboardType="numbers-and-punctuation"
          onSubmitEditing={() => add(normalizeTime(draft))}
          style={st.input}
        />
        <Pressable onPress={() => add(normalizeTime(draft))} style={st.addBtn}>
          <Ionicons name="add" size={22} color="#fff" />
        </Pressable>
      </View>
    </View>
  );
}

const st = StyleSheet.create({
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, alignItems: 'center' },
  time: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: C.primarySoft, paddingHorizontal: 12, paddingVertical: 7, borderRadius: 99 },
  preset: { alignItems: 'center', paddingHorizontal: 14, paddingVertical: 6, borderRadius: R.sm, borderWidth: 1.5, borderColor: C.line, backgroundColor: C.surface },
  input: { flex: 1, fontFamily: F.medium, fontSize: 15, borderWidth: 1.5, borderColor: C.line, borderRadius: R.md, paddingHorizontal: 12, paddingVertical: 10, backgroundColor: C.surface, color: C.ink },
  addBtn: { width: 46, borderRadius: R.md, backgroundColor: C.primary, alignItems: 'center', justifyContent: 'center' },
});
