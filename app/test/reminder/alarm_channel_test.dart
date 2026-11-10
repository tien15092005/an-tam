import 'package:app/reminder/alarm_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // On iPhone (and in tests) there is no native alarm engine. The router asks "is an alarm ringing?" on every
  // navigation, so these must answer "nothing" instead of throwing, or the caregiver app could not move at all.
  test('without the native alarm engine nothing is ringing and nothing throws', () async {
    expect(await AlarmChannel.ringingId(), isNull);
    expect(await AlarmChannel.ringingIds(), isEmpty);
    await AlarmChannel.setBackgroundSync(true);
  });

  test('the alarm engine is Android only', () {
    expect(AlarmChannel.supported, isTrue, reason: 'flutter test runs as Android by default');
  });
}
