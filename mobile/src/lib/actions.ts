import type { AgendaEntry } from '@/components/agenda';
import { api } from './api';

// Người con đánh dấu giúp (hoặc hoàn tác) một lần uống thuốc / buổi tập
export async function toggleEntry(elderId: number, e: AgendaEntry) {
  const it: any = e.item;
  const finished = ['taken', 'skipped', 'done'].includes(it.status);
  if (e.kind === 'dose') {
    await api.post(`/elders/${elderId}/doses`, { med_id: it.med_id, time: it.time, date: it.date, status: finished ? 'clear' : 'taken' });
  } else {
    await api.post(`/elders/${elderId}/exercise-logs`, { exercise_id: it.exercise_id, date: it.date, status: finished ? 'clear' : 'done' });
  }
}
