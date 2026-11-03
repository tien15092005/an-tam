import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, Pressable, Share, StyleSheet, View } from 'react-native';
import { Button, Card, ErrorText, Field, Screen, SectionHeader, T } from '@/components/ui';
import { api, getServerUrl, type Elder } from '@/lib/api';
import { useApp } from '@/lib/app-state';
import { C, F } from '@/lib/theme';

export default function Settings() {
  const { user, elders, elder, selectElder, reloadElders, signOut } = useApp();
  const [detail, setDetail] = useState<(Elder & { members: { id: number; name: string; email: string }[] }) | null>(null);
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    await reloadElders().catch(() => {});
    if (elder) setDetail(await api.get(`/elders/${elder.id}`).catch(() => null));
  }, [elder?.id]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  async function regen() {
    Alert.alert('Tạo mã mới?', 'Điện thoại của bố mẹ sẽ phải nhập lại mã mới.', [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Tạo mã mới', onPress: async () => { await api.post(`/elders/${elder!.id}/regen-code`); load(); } },
    ]);
  }

  async function share() {
    setError('');
    try {
      await api.post(`/elders/${elder!.id}/share`, { email });
      setEmail('');
      load();
    } catch (e: any) { setError(e.message); }
  }

  function remove() {
    Alert.alert('Xóa hồ sơ?', 'Bạn sẽ ngừng theo dõi hồ sơ này. Nếu không còn ai theo dõi, dữ liệu sẽ bị xóa.', [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Xóa', style: 'destructive', onPress: async () => { await api.del(`/elders/${elder!.id}`); setDetail(null); load(); } },
    ]);
  }

  return (
    <Screen>
      <T size={24} weight="black">Cài đặt</T>

      <SectionHeader title="Bố mẹ" action={<Button title="Thêm" icon="add" kind="soft" size="sm" onPress={() => router.push('/elder-form')} />} />
      <Card style={{ paddingVertical: 4 }}>
        {elders.map(e => (
          <Pressable key={e.id} onPress={() => selectElder(e.id)} style={st.row}>
            <Ionicons name={e.id === elder?.id ? 'radio-button-on' : 'radio-button-off'} size={22} color={e.id === elder?.id ? C.primary : C.muted} />
            <T weight="semi" style={{ flex: 1 }}>{e.name}</T>
            <T size={13} color={C.muted}>{e.phone}</T>
          </Pressable>
        ))}
        {!elders.length && <T color={C.muted} style={{ padding: 12 }}>Chưa có hồ sơ nào</T>}
      </Card>

      {detail && (
        <>
          <Card style={{ gap: 8, alignItems: 'center', backgroundColor: C.navy }}>
            <T size={13} color="#C9D2EC">Mã đăng nhập của {detail.name}</T>
            <T size={40} color="#fff" style={{ fontFamily: F.black, letterSpacing: 8 }}>{detail.login_code}</T>
            <T size={12.5} color="#C9D2EC" center>Trên điện thoại của bố mẹ: mở An Tâm → “Tôi là bố / mẹ” → nhập mã này.</T>
            <View style={{ flexDirection: 'row', gap: 8, marginTop: 4 }}>
              <Button title="Gửi mã" icon="share-outline" kind="primary" size="sm"
                onPress={() => Share.share({ message: `Mã đăng nhập An Tâm của ${detail.name}: ${detail.login_code}` })} />
              <Button title="Tạo mã mới" kind="ghost" size="sm" onPress={regen} style={{ borderColor: '#4B5C8E' }} />
            </View>
          </Card>

          <SectionHeader title="Người cùng theo dõi" />
          <Card style={{ gap: 10 }}>
            {detail.members.map(m => (
              <View key={m.id} style={{ flexDirection: 'row', gap: 10, alignItems: 'center' }}>
                <Ionicons name="person-circle-outline" size={26} color={C.navy} />
                <View><T weight="semi">{m.name}</T><T size={12} color={C.muted}>{m.email}</T></View>
              </View>
            ))}
            <Field label="Mời anh / chị / em (email đã đăng ký)" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
            <ErrorText text={error} />
            <Button title="Mời theo dõi" kind="ghost" size="sm" onPress={share} disabled={!email} />
          </Card>
          <Button title={`Xóa hồ sơ ${detail.name}`} kind="danger" size="sm" onPress={remove} />
        </>
      )}

      <SectionHeader title="Tài khoản" />
      <Card style={{ gap: 4 }}>
        <T weight="semi">{user?.name}</T>
        <T size={13} color={C.muted}>{user?.email}</T>
        <T size={12} color={C.muted}>Máy chủ: {getServerUrl()}</T>
      </Card>
      <Button title="Đăng xuất" icon="log-out-outline" kind="ghost" onPress={async () => { await signOut(); router.replace('/login'); }} />
    </Screen>
  );
}

const st = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 12 },
});
