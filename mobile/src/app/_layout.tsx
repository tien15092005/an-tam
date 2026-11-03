import {
  BeVietnamPro_400Regular, BeVietnamPro_500Medium, BeVietnamPro_600SemiBold, BeVietnamPro_700Bold,
  BeVietnamPro_800ExtraBold, useFonts,
} from '@expo-google-fonts/be-vietnam-pro';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Loading } from '@/components/ui';
import { AppProvider, useApp } from '@/lib/app-state';
import { C, F } from '@/lib/theme';

function RootStack() {
  const { ready } = useApp();
  if (!ready) return <Loading />;
  return (
    <Stack
      id={undefined}
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: C.bg },
        headerStyle: { backgroundColor: C.bg },
        headerShadowVisible: false,
        headerTitleStyle: { fontFamily: F.bold, fontSize: 17, color: C.ink },
        headerTintColor: C.ink,
      }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen name="login" />
      <Stack.Screen name="(child)" />
      <Stack.Screen name="elder" />
      <Stack.Screen name="med-form" options={{ presentation: 'modal', headerShown: true, title: 'Thuốc' }} />
      <Stack.Screen name="exercise-form" options={{ presentation: 'modal', headerShown: true, title: 'Lịch tập thể dục' }} />
      <Stack.Screen name="ocr" options={{ presentation: 'modal', headerShown: true, title: 'Quét toa thuốc' }} />
      <Stack.Screen name="elder-form" options={{ presentation: 'modal', headerShown: true, title: 'Thêm bố / mẹ' }} />
      <Stack.Screen name="health-form" options={{ presentation: 'modal', headerShown: true, title: 'Ghi chỉ số sức khỏe' }} />
    </Stack>
  );
}

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    BeVietnamPro_400Regular, BeVietnamPro_500Medium, BeVietnamPro_600SemiBold, BeVietnamPro_700Bold, BeVietnamPro_800ExtraBold,
  });
  if (!fontsLoaded) return <Loading />;
  return (
    <SafeAreaProvider>
      <AppProvider>
        <StatusBar style="dark" />
        <RootStack />
      </AppProvider>
    </SafeAreaProvider>
  );
}
