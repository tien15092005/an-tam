import 'package:app/features/chat/chat_api.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage msg(int? id, {String? cid, String body = 'x', bool deleted = false}) => ChatMessage(
    id: id, groupId: 1, senderId: 5, system: false, body: deleted ? null : body, clientMessageId: cid,
    createdAt: DateTime(2026, 11, 9), deleted: deleted);

void main() {
  test('a sent message replaces its pending copy and each id appears once', () {
    var list = mergeMessages(const [], [msg(1), msg(2)]);
    list = mergeMessages(list, [msg(null, cid: 'a', body: 'đang gửi')]);
    expect(list.map((m) => m.id), [1, 2, null]);
    // The socket event and the HTTP answer for the same message both arrive.
    list = mergeMessages(list, [msg(3, cid: 'a', body: 'đang gửi')]);
    list = mergeMessages(list, [msg(3, cid: 'a', body: 'đang gửi')]);
    expect(list.map((m) => m.id), [1, 2, 3]);
  });

  test('older pages go in front, a deletion replaces the text', () {
    var list = mergeMessages(const [], [msg(10), msg(11)]);
    list = mergeMessages(list, [msg(7), msg(8)]);
    list = mergeMessages(list, [msg(11, deleted: true)]);
    expect(list.map((m) => m.id), [7, 8, 10, 11]);
    expect(list.last.deleted, isTrue);
    expect(list.last.body, isNull);
  });

  test('a failed send stays at the end until retried', () {
    var list = mergeMessages([msg(1)], [msg(null, cid: 'b').copyWith(failed: true)]);
    list = mergeMessages(list, [msg(2)]);
    expect(list.map((m) => m.id), [1, 2, null]);
    expect(list.last.failed, isTrue);
  });
}
