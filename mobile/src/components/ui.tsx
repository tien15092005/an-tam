import { Ionicons } from '@expo/vector-icons';
import type { ComponentProps, ReactNode } from 'react';
import {
  ActivityIndicator, Pressable, RefreshControl, ScrollView, StyleSheet, Text, TextInput, View,
  type StyleProp, type TextInputProps, type TextStyle, type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { C, F, R, STATUS, shadow } from '@/lib/theme';
import type { Status } from '@/lib/api';

export type IconName = ComponentProps<typeof Ionicons>['name'];

type TProps = {
  children: ReactNode;
  size?: number;
  weight?: keyof typeof F;
  color?: string;
  style?: StyleProp<TextStyle>;
  numberOfLines?: number;
  center?: boolean;
};

// Chữ dùng font Be Vietnam Pro (React Native không kế thừa font từ cha)
export function T({ children, size = 15, weight = 'regular', color = C.ink, style, numberOfLines, center }: TProps) {
  return (
    <Text
      numberOfLines={numberOfLines}
      style={[{ fontFamily: F[weight], fontSize: size, color, lineHeight: Math.round(size * 1.38) }, center && { textAlign: 'center' }, style]}
    >
      {children}
    </Text>
  );
}

export function Screen({ children, refreshing, onRefresh, scroll = true, style, edges }: {
  children: ReactNode; refreshing?: boolean; onRefresh?: () => void; scroll?: boolean;
  style?: StyleProp<ViewStyle>; edges?: ('top' | 'bottom')[];
}) {
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={edges ?? ['top']}>
      {scroll ? (
        <ScrollView
          contentContainerStyle={[{ padding: 18, paddingBottom: 40, gap: 14 }, style]}
          refreshControl={onRefresh ? <RefreshControl refreshing={!!refreshing} onRefresh={onRefresh} tintColor={C.primary} /> : undefined}
          keyboardShouldPersistTaps="handled"
        >
          {children}
        </ScrollView>
      ) : (
        <View style={[{ flex: 1, padding: 18 }, style]}>{children}</View>
      )}
    </SafeAreaView>
  );
}

export function Card({ children, style, onPress }: { children: ReactNode; style?: StyleProp<ViewStyle>; onPress?: () => void }) {
  const body = <View style={[s.card, style]}>{children}</View>;
  return onPress ? <Pressable onPress={onPress} style={({ pressed }) => pressed && { opacity: 0.85 }}>{body}</Pressable> : body;
}

type BtnKind = 'primary' | 'navy' | 'ok' | 'ghost' | 'soft' | 'danger';
const BTN: Record<BtnKind, { bg: string; fg: string; border?: string }> = {
  primary: { bg: C.primary, fg: '#fff' },
  navy: { bg: C.navy, fg: '#fff' },
  ok: { bg: C.ok, fg: '#fff' },
  danger: { bg: C.surface, fg: C.danger, border: C.danger },
  soft: { bg: C.primarySoft, fg: C.primaryDark },
  ghost: { bg: 'transparent', fg: C.ink, border: C.line },
};

export function Button({ title, onPress, kind = 'primary', icon, loading, disabled, size = 'md', style }: {
  title: string; onPress?: () => void; kind?: BtnKind; icon?: IconName; loading?: boolean; disabled?: boolean;
  size?: 'sm' | 'md' | 'lg' | 'xl'; style?: StyleProp<ViewStyle>;
}) {
  const k = BTN[kind];
  const pad = { sm: 8, md: 13, lg: 18, xl: 26 }[size];
  const fs = { sm: 13, md: 15, lg: 19, xl: 26 }[size];
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        s.btn,
        { backgroundColor: k.bg, paddingVertical: pad, borderColor: k.border ?? k.bg, borderRadius: size === 'xl' ? R.xl : R.md },
        (disabled || loading) && { opacity: 0.5 },
        pressed && { transform: [{ scale: 0.98 }], opacity: 0.9 },
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={k.fg} /> : icon ? <Ionicons name={icon} size={fs + 4} color={k.fg} /> : null}
      <T size={fs} weight="bold" color={k.fg}>{title}</T>
    </Pressable>
  );
}

export function Chip({ label, active, onPress, color = C.primary }: { label: string; active?: boolean; onPress?: () => void; color?: string }) {
  return (
    <Pressable onPress={onPress} style={[s.chip, active && { backgroundColor: color, borderColor: color }]}>
      <T size={13} weight="semi" color={active ? '#fff' : C.ink}>{label}</T>
    </Pressable>
  );
}

export function Field({ label, hint, ...props }: TextInputProps & { label: string; hint?: string }) {
  return (
    <View style={{ gap: 6 }}>
      <T size={13} weight="semi" color={C.muted}>{label}</T>
      <TextInput placeholderTextColor="#A8A39B" {...props} style={[s.input, props.multiline && { minHeight: 80, textAlignVertical: 'top' }, props.style]} />
      {hint ? <T size={12} color={C.muted}>{hint}</T> : null}
    </View>
  );
}

export function StatusPill({ status }: { status: Status }) {
  const st = STATUS[status];
  return (
    <View style={[s.pill, { backgroundColor: st.bg }]}>
      <T size={12} weight="semi" color={st.color}>{st.label}</T>
    </View>
  );
}

export function IconBadge({ name, color, bg, size = 40 }: { name: IconName; color: string; bg: string; size?: number }) {
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2.6, backgroundColor: bg, alignItems: 'center', justifyContent: 'center' }}>
      <Ionicons name={name} size={size * 0.5} color={color} />
    </View>
  );
}

export function SectionHeader({ title, action }: { title: string; action?: ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
      <T size={17} weight="bold">{title}</T>
      {action}
    </View>
  );
}

export function Empty({ icon = 'leaf-outline', text }: { icon?: IconName; text: string }) {
  return (
    <View style={{ alignItems: 'center', padding: 28, gap: 8 }}>
      <Ionicons name={icon} size={34} color="#C9C1B6" />
      <T color={C.muted} center>{text}</T>
    </View>
  );
}

export function ErrorText({ text }: { text?: string | null }) {
  return text ? <T size={13} color={C.danger}>{text}</T> : null;
}

export function Loading() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: C.bg }}>
      <ActivityIndicator size="large" color={C.primary} />
    </View>
  );
}

const s = StyleSheet.create({
  card: { backgroundColor: C.surface, borderRadius: R.lg, padding: 16, ...shadow },
  btn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, paddingHorizontal: 18, borderWidth: 1.5 },
  chip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 99, borderWidth: 1.5, borderColor: C.line, backgroundColor: C.surface },
  input: {
    fontFamily: F.medium, fontSize: 16, color: C.ink, backgroundColor: C.surface,
    borderWidth: 1.5, borderColor: C.line, borderRadius: R.md, paddingHorizontal: 14, paddingVertical: 12,
  },
  pill: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 99, alignSelf: 'flex-start' },
});
