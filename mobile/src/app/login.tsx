import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, TextInput, View } from 'react-native';
import { Button, Card, ErrorText, Field, Screen, T } from '@/components/ui';
import { api, getServerUrl, setServerUrl, type User } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { C, F, R } from '@/lib/theme';

type Mode = 'choose' | 'elder' | 'login' | 'register';

export default function Login() {
  const { signIn } = useApp();
  const [mode, setMode] = useState<Mode>('choose');
  const [form, setForm] = useState({ name: '', email: '', phone: '', password: '', code: '' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [showServer, setShowServer] = useState(false);
  const [server, setServer] = useState(getServerUrl());
  const set = (k: keyof typeof form) => (v: string) => setForm(f => ({ ...f, [k]: v }));

  async function submit() {
    setError('');
    setBusy(true);
    try {
      const path = mode === 'elder' ? '/auth/elder-login' : mode === 'login' ? '/auth/login' : '/auth/register';
      const res = await api.post<{ token: string; user: User }>(path, form);
      if (res.user.role === 'admin') throw new Error('Tài khoản admin dùng trang quản trị trên web.');
      await signIn(res.token, res.user);
      router.replace('/');
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Screen style={{ paddingTop: 40, gap: 18 }}>
        <View style={{ alignItems: 'center', gap: 6, marginBottom: 10 }}>
          <View style={st.logo}><Ionicons name="heart" size={38} color="#fff" /></View>
          <T size={32} weight="black" color={C.ink}>An Tâm</T>
          <T color={C.muted} center>Nhắc bố mẹ uống thuốc, con ở xa vẫn yên tâm</T>
        </View>

        {mode === 'choose' && (
          <View style={{ gap: 14 }}>
            <RoleCard
              icon="happy-outline" color={C.primary} bg={C.primarySoft}
              title="Tôi là bố / mẹ" sub="Chỉ cần nhập mã 6 số con gửi"
              onPress={() => setMode('elder')}
            />
            <RoleCard
              icon="people-outline" color={C.navy} bg={C.navySoft}
              title="Tôi là người con" sub="Theo dõi thuốc, lịch tập và sức khỏe của bố mẹ"
              onPress={() => setMode('login')}
            />
          </View>
        )}

        {mode === 'elder' && (
          <Card style={{ gap: 14 }}>
            <T size={22} weight="bold" center>Nhập mã của bạn</T>
            <TextInput
              value={form.code}
              onChangeText={v => set('code')(v.replace(/\D/g, '').slice(0, 6))}
              keyboardType="number-pad"
              maxLength={6}
              placeholder="••••••"
              placeholderTextColor="#CFC8BE"
              style={st.code}
              autoFocus
            />
            <ErrorText text={error} />
            <Button title="Vào ứng dụng" size="lg" onPress={submit} loading={busy} disabled={form.code.length !== 6} />
          </Card>
        )}

        {(mode === 'login' || mode === 'register') && (
          <Card style={{ gap: 14 }}>
            <View style={st.tabs}>
              {(['login', 'register'] as const).map(m => (
                <Pressable key={m} onPress={() => setMode(m)} style={[st.tab, mode === m && st.tabOn]}>
                  <T weight="semi" color={mode === m ? C.ink : C.muted}>{m === 'login' ? 'Đăng nhập' : 'Đăng ký'}</T>
                </Pressable>
              ))}
            </View>
            {mode === 'register' && <Field label="Họ tên" value={form.name} onChangeText={set('name')} />}
            <Field label="Email" value={form.email} onChangeText={set('email')} keyboardType="email-address" autoCapitalize="none" />
            {mode === 'register' && <Field label="Số điện thoại" hint="Để bố mẹ bấm gọi cho bạn" value={form.phone} onChangeText={set('phone')} keyboardType="phone-pad" />}
            <Field label="Mật khẩu" value={form.password} onChangeText={set('password')} secureTextEntry />
            <ErrorText text={error} />
            <Button title={mode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản'} kind="navy" onPress={submit} loading={busy} />
          </Card>
        )}

        {mode !== 'choose' && (
          <Button title="Quay lại" kind="ghost" icon="arrow-back" onPress={() => { setMode('choose'); setError(''); }} />
        )}

        <Pressable onPress={() => setShowServer(v => !v)} style={{ alignSelf: 'center', padding: 8 }}>
          <T size={12} color={C.muted}>Máy chủ: {getServerUrl()}</T>
        </Pressable>
        {showServer && (
          <Card style={{ gap: 10 }}>
            <Field label="Địa chỉ máy chủ" hint="Để trống để tự nhận theo máy tính đang chạy Expo" value={server} onChangeText={setServer} autoCapitalize="none" />
            <Button title="Lưu" kind="ghost" size="sm" onPress={async () => { await setServerUrl(server); setServer(getServerUrl()); setShowServer(false); }} />
          </Card>
        )}
      </Screen>
    </KeyboardAvoidingView>
  );
}

function RoleCard({ icon, color, bg, title, sub, onPress }: any) {
  return (
    <Card onPress={onPress} style={{ flexDirection: 'row', alignItems: 'center', gap: 16, padding: 20 }}>
      <View style={{ width: 60, height: 60, borderRadius: 20, backgroundColor: bg, alignItems: 'center', justifyContent: 'center' }}>
        <Ionicons name={icon} size={32} color={color} />
      </View>
      <View style={{ flex: 1 }}>
        <T size={19} weight="bold">{title}</T>
        <T size={14} color={C.muted}>{sub}</T>
      </View>
      <Ionicons name="chevron-forward" size={22} color={C.muted} />
    </Card>
  );
}

const st = StyleSheet.create({
  logo: { width: 76, height: 76, borderRadius: 26, backgroundColor: C.primary, alignItems: 'center', justifyContent: 'center', transform: [{ rotate: '-6deg' }] },
  code: { fontFamily: F.black, fontSize: 40, letterSpacing: 12, textAlign: 'center', color: C.ink, backgroundColor: C.bg, borderRadius: R.md, paddingVertical: 14 },
  tabs: { flexDirection: 'row', backgroundColor: C.grey, borderRadius: R.md, padding: 4 },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 9, borderRadius: R.sm },
  tabOn: { backgroundColor: C.surface },
});
