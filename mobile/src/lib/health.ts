import type { IconName } from '@/components/ui';
import type { HealthRecord } from './api';

export const HEALTH: Record<string, { label: string; unit: string; icon: IconName; bad: (r: HealthRecord) => boolean }> = {
  bp: { label: 'Huyết áp', unit: 'mmHg', icon: 'heart-outline', bad: r => r.value >= 140 || r.value < 90 || (r.value2 ?? 0) >= 90 || (r.value2 ?? 70) < 60 },
  hr: { label: 'Nhịp tim', unit: 'lần/phút', icon: 'pulse-outline', bad: r => r.value < 60 || r.value > 100 },
  sugar: { label: 'Đường huyết', unit: 'mmol/L', icon: 'water-outline', bad: r => r.value < 3.9 || r.value > 7 },
  spo2: { label: 'SpO₂', unit: '%', icon: 'fitness-outline', bad: r => r.value < 95 },
  temp: { label: 'Nhiệt độ', unit: '°C', icon: 'thermometer-outline', bad: r => r.value < 36 || r.value >= 37.6 },
  weight: { label: 'Cân nặng', unit: 'kg', icon: 'barbell-outline', bad: () => false },
};

const num = (v: number | null) => (v == null ? '' : String(Math.round(v * 10) / 10));
export const healthValue = (r: HealthRecord) => (r.type === 'bp' ? `${num(r.value)}/${num(r.value2)}` : num(r.value));
