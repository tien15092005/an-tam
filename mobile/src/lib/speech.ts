import * as Speech from 'expo-speech';

// Dùng giọng tiếng Việt có sẵn trên điện thoại (Android: Google TTS, iPhone: Linh).
let viVoice: string | undefined;
let checked = false;

async function findVietnameseVoice() {
  if (checked) return viVoice;
  checked = true;
  try {
    const voices = await Speech.getAvailableVoicesAsync();
    const vi = voices.filter(v => /^vi/i.test(v.language));
    viVoice = (vi.find(v => v.quality === Speech.VoiceQuality.Enhanced) || vi[0])?.identifier;
  } catch {}
  return viVoice;
}

export async function hasVietnameseVoice() {
  return !!(await findVietnameseVoice());
}

export async function speak(text: string, onDone?: () => void) {
  await Speech.stop();
  const voice = await findVietnameseVoice();
  Speech.speak(text, {
    language: 'vi-VN',
    voice,
    rate: 0.9,
    onDone,
    onError: () => onDone?.(),
  });
}

export function stopSpeaking() {
  Speech.stop();
}
