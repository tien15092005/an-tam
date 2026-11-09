// Understanding the elder's spoken answers (plan §9). Deliberately strict: when unsure, do nothing
// and keep reminding. Above all, anything with "chưa" / "không" never counts as taken.

enum ConfirmIntent { taken, snooze, notTaken, unknown }

enum IssueIntent { none, lost, outOf, unsure, unwell, other, unknown }

/// Lower-case, strip Vietnamese diacritics and punctuation, so "Đã uống rồi!" and "da uong roi" match alike
/// (recognisers and keyboards differ in whether they keep the marks).
String normalizeVi(String input) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final lower = input.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return ' ${b.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
}

bool _has(String n, List<String> phrases) => phrases.any((p) => n.contains(' $p '));

const _negations = ['chua', 'khong', 'ko', 'k uong', 'hong', 'quen'];

ConfirmIntent classifyConfirm(String heard) {
  final n = normalizeVi(heard);
  if (n.trim().isEmpty) return ConfirmIntent.unknown;
  // "Lát nữa", "chờ chút": a later reminder, not a confirmation.
  if (_has(n, ['lat nua', 'lat', 'cho chut', 'cho mot chut', 'doi chut', 'de sau', 'nhac lai', 'chut nua'])) {
    return ConfirmIntent.snooze;
  }
  // Checked before "taken": "chưa uống", "không uống được", "uống chưa" all contain "uống".
  if (_has(n, _negations)) {
    return _has(n, ['khong uong duoc', 'khong uong', 'khong the uong']) ? ConfirmIntent.notTaken : ConfirmIntent.unknown;
  }
  if (_has(n, ['da uong', 'uong roi', 'xong roi', 'uong xong', 'roi a', 'da xong'])) return ConfirmIntent.taken;
  return ConfirmIntent.unknown;
}

IssueIntent classifyIssue(String heard) {
  final n = normalizeVi(heard);
  if (n.trim().isEmpty) return IssueIntent.unknown;
  final matches = <IssueIntent>{
    if (_has(n, ['mat thuoc', 'lam mat', 'roi mat', 'khong thay thuoc', 'tim khong thay'])) IssueIntent.lost,
    if (_has(n, ['het thuoc', 'het roi', 'khong con thuoc', 'het'])) IssueIntent.outOf,
    if (_has(n, ['trong khac', 'khac mau', 'la qua', 'khong chac', 'khong giong', 'thuoc la'])) IssueIntent.unsure,
    // Without diacritics "đau" (pain) equals "đâu" (a filler word), so pain only counts with a body word.
    if (_has(n, ['met', 'thay met', 'khong khoe', 'bi dau', 'dau qua', 'dau dau', 'dau bung', 'dau nguc', 'chong mat',
      'buon non', 'kho tho', 'om'])) IssueIntent.unwell,
    if (_has(n, ['van de khac', 'chuyen khac', 'goi con'])) IssueIntent.other,
  };
  if (matches.length > 1) return IssueIntent.unknown; // Two different problems heard: do not guess.
  if (matches.length == 1) return matches.first;
  if (_has(n, ['khong co gi', 'khong sao', 'binh thuong', 'on', 'van on', 'khong', 'khong co'])) return IssueIntent.none;
  return IssueIntent.unknown;
}
