import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/tokens.dart';
import '../../reminder/alarm_channel.dart';

/// "Bấm để nói": listens once in Vietnamese and hands the words to [onHeard]. The alarm voice is
/// paused while listening so the microphone does not hear the phone. Only listens after a press,
/// never in the background (plan §9: the microphone is used only during the answer).
class VoiceButton extends StatefulWidget {
  const VoiceButton({super.key, required this.onHeard, this.foreground = Colors.white});

  final void Function(String words) onHeard;
  final Color foreground;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  static const _explainedKey = 'mic_explained';
  final _speech = SpeechToText();
  bool _listening = false;
  String _heard = '';

  Future<bool> _explainOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_explainedKey) == true) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trả lời bằng giọng nói'),
        content: const Text('Máy cần dùng micro để nghe câu trả lời, ví dụ "đã uống rồi". '
            'Máy chỉ nghe khi bấm nút này, không ghi âm lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (ok == true) await prefs.setBool(_explainedKey, true);
    return ok == true;
  }

  Future<void> _listen() async {
    if (_listening) return;
    if (!await _explainOnce()) return;
    final available = await _speech.initialize(onError: (_) => _stop(), onStatus: (s) {
      if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _stop();
    });
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máy chưa nghe được giọng nói. Hãy bấm nút trên màn hình.')));
      }
      return;
    }
    try {
      await AlarmChannel.holdSpeech(const Duration(seconds: 12));
      await AlarmChannel.stopSpeaking();
    } catch (_) {
      // Not ringing (e.g. the question screen): nothing to pause.
    }
    setState(() {
      _listening = true;
      _heard = '';
    });
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult) {
          _stop();
          widget.onHeard(r.recognizedWords);
        }
      },
    );
  }

  void _stop() {
    if (!mounted || !_listening) return;
    _speech.stop();
    setState(() => _listening = false);
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = widget.foreground;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: fg.withValues(alpha: 0.7), width: 2),
          minimumSize: const Size(0, 64),
        ),
        onPressed: _listening ? _stop : _listen,
        icon: Icon(_listening ? Icons.hearing : Icons.mic, size: 32),
        label: Text(_listening ? 'Đang nghe...' : 'Bấm để nói'),
      ),
      if (_heard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text('"$_heard"', style: text.bodyLarge?.copyWith(color: fg), textAlign: TextAlign.center),
        ),
    ]);
  }
}
