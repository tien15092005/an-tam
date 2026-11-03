import { Ionicons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';
import { Redirect, Tabs } from 'expo-router';
import { useApp } from '@/lib/app-state';
import { C, F } from '@/lib/theme';

function tabIcon(name: ComponentProps<typeof Ionicons>['name']) {
  return function TabIcon({ color, size }: { color: any; size: number }) {
    return <Ionicons name={name} size={size} color={color} />;
  };
}

export default function ChildTabs() {
  const { user } = useApp();
  if (!user) return <Redirect href="/login" />;
  return (
    <Tabs
      id={undefined}
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: C.primary,
        tabBarInactiveTintColor: C.muted,
        tabBarLabelStyle: { fontFamily: F.semi, fontSize: 11.5 },
        tabBarStyle: { backgroundColor: C.surface, borderTopColor: C.line, height: 64, paddingTop: 6 },
        sceneStyle: { backgroundColor: C.bg },
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Hôm nay', tabBarIcon: tabIcon('home-outline') }} />
      <Tabs.Screen name="calendar" options={{ title: 'Lịch', tabBarIcon: tabIcon('calendar-outline') }} />
      <Tabs.Screen name="health" options={{ title: 'Sức khỏe', tabBarIcon: tabIcon('pulse-outline') }} />
      <Tabs.Screen name="settings" options={{ title: 'Cài đặt', tabBarIcon: tabIcon('settings-outline') }} />
    </Tabs>
  );
}
