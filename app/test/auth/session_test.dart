import 'dart:convert';

import 'package:app/features/auth/session.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object> claims) {
  String part(Map<String, Object> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
}

void main() {
  test('an elder phone is recognised from its token, so an expired session keeps its alarms', () {
    final elder = Session(accessToken: jwt({'sub': '42', 'typ': 'ELDER'}), refreshToken: 'r');
    final caregiver = Session(accessToken: jwt({'sub': '7', 'typ': 'CAREGIVER'}), refreshToken: 'r');
    expect(elder.isElder, isTrue);
    expect(caregiver.isElder, isFalse);
    expect(elder.userId, '42');
  });

  test('an expired session keeps its tokens and survives a restart', () {
    final s = Session(accessToken: jwt({'sub': '42', 'typ': 'ELDER'}), refreshToken: 'r').asExpired();
    expect(s.expired, isTrue);
    expect(s.refreshToken, 'r');
    expect(s.toJson()['expired'], isTrue);
    expect(Session.fromTokenResponse({'accessToken': 'a', 'refreshToken': 'b'}).expired, isFalse);
  });

  test('a malformed token is simply not an elder', () {
    expect(const Session(accessToken: 'not-a-jwt', refreshToken: 'r').isElder, isFalse);
  });
}
