import { Redirect } from 'expo-router';
import { useApp } from '@/lib/app-state';

// Điều hướng theo vai trò sau khi mở app
export default function Index() {
  const { user } = useApp();
  if (!user) return <Redirect href="/login" />;
  if (user.role === 'elder') return <Redirect href="/elder" />;
  return <Redirect href="/(child)" />;
}
