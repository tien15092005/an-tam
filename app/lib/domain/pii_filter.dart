import 'voice_intent.dart' show normalizeVi;

/// Lines that identify a person are removed on the phone, before the text leaves it (plan §8).
/// The AI service runs the same check again (ai-service/app/parsing/privacy.py).
final _personalLabel = RegExp(
  r'^\W*(ho ten|ho va ten|ten benh nhan|benh nhan|nguoi benh|khach hang|ten khach|nguoi mua|'
  r'dia chi|so dien thoai|dien thoai|sdt|dt|so the|ma the|bhyt|cmnd|cccd|can cuoc|ma so|ma benh nhan|ma bn|'
  r'nam sinh|ngay sinh|tuoi|gioi tinh|can nang|chan doan|email|so ho so|ma ho so)\b',
);
final _phone = RegExp(r'(?<!\d)(?:\+?84|0)(?:[\s.-]?\d){8,10}(?!\d)');
final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
final _longId = RegExp(r'(?<!\d)\d{9,}(?!\d)');

bool isPersonalLine(String line) =>
    _personalLabel.hasMatch(normalizeVi(line)) || _phone.hasMatch(line) || _email.hasMatch(line) || _longId.hasMatch(line);

/// The text with personal lines dropped, and how many were dropped (shown to the caregiver).
({String text, int removed}) removePersonalLines(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final kept = lines.where((l) => !isPersonalLine(l)).toList();
  return (text: kept.join('\n'), removed: lines.length - kept.length);
}
