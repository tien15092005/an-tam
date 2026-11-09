import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/server_config.dart';
import '../../reminder/outbox.dart' show newEventId;
import '../auth/session.dart';
import '../groups/groups_api.dart' show meProvider;
import 'chat_api.dart';

class ChatState {
  const ChatState({this.messages = const [], this.loading = true, this.live = false, this.hasOlder = true, this.error});
  final List<ChatMessage> messages;
  final bool loading;

  /// True while the socket is subscribed; otherwise new messages arrive on the next refresh.
  final bool live;
  final bool hasOlder;
  final String? error;

  ChatState copyWith({List<ChatMessage>? messages, bool? loading, bool? live, bool? hasOlder, String? error, bool clearError = false}) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        live: live ?? this.live,
        hasOlder: hasOlder ?? this.hasOlder,
        error: clearError ? null : (error ?? this.error),
      );
}

/// One group's chat: REST for history and sending, a WebSocket for live messages. After any disconnect it
/// reconnects with a growing delay and reloads the latest page, so nothing missed stays missing.
class ChatController extends Notifier<ChatState> {
  ChatController(this.groupId);
  final int groupId;

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _backoff = 1;
  bool _disposed = false;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  ChatState build() {
    ref.onDispose(() {
      _disposed = true;
      _retry?.cancel();
      _sub?.cancel();
      _ws?.sink.close();
    });
    Future.microtask(() async {
      await reload();
      _connect();
    });
    return const ChatState();
  }

  Future<void> reload() async {
    try {
      final latest = await _api.history(groupId);
      state = state.copyWith(
          messages: mergeMessages(state.messages, latest), loading: false, hasOlder: latest.length >= 30, clearError: true);
      _markRead();
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không tải được tin nhắn. Kéo xuống để thử lại.');
    }
  }

  Future<void> loadOlder() async {
    final oldest = state.messages.where((m) => m.id != null).map((m) => m.id!).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    if (oldest == null || !state.hasOlder) return;
    try {
      final older = await _api.history(groupId, before: oldest);
      state = state.copyWith(messages: mergeMessages(state.messages, older), hasOlder: older.length >= 30);
    } catch (_) {
      // Shown again on the next scroll.
    }
  }

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final pending = ChatMessage(
      groupId: groupId,
      senderId: ref.read(meProvider).value?.id,
      system: false,
      body: body,
      clientMessageId: newEventId(),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: mergeMessages(state.messages, [pending]));
    await _deliver(pending);
  }

  /// Same clientMessageId as the first try: the server keeps one copy.
  Future<void> retry(ChatMessage m) async {
    state = state.copyWith(messages: mergeMessages(state.messages, [m.copyWith(failed: false)]));
    await _deliver(m);
  }

  Future<void> _deliver(ChatMessage m) async {
    try {
      final sent = await _api.send(groupId, m.clientMessageId!, m.body!);
      state = state.copyWith(messages: mergeMessages(state.messages, [sent]));
    } catch (_) {
      state = state.copyWith(messages: mergeMessages(state.messages, [m.copyWith(failed: true)]));
    }
  }

  Future<void> delete(ChatMessage m) async {
    if (m.id == null) return;
    await _api.delete(groupId, m.id!);
    await reload();
  }

  void _markRead() {
    int? last;
    for (final m in state.messages) {
      if (m.id != null && (last == null || m.id! > last)) last = m.id;
    }
    if (last != null) _api.markRead(groupId, last).catchError((_) {});
  }

  void _connect() {
    if (_disposed) return;
    final token = ref.read(sessionProvider).value?.accessToken;
    if (token == null) return;
    final base = ref.read(serverUrlProvider);
    final url = Uri.parse(base.replaceFirst(RegExp(r'^http'), 'ws')).replace(path: '/ws/chat');
    try {
      final ws = IOWebSocketChannel.connect(url, headers: {'Authorization': 'Bearer $token'}, pingInterval: const Duration(seconds: 25));
      _ws = ws;
      _sub = ws.stream.listen(_onFrame, onError: (_) => _lost(), onDone: _lost);
      ws.ready.then((_) {
        ws.sink.add(jsonEncode({'type': 'subscribe', 'groupId': groupId}));
      }).catchError((_) => _lost());
    } catch (_) {
      _lost();
    }
  }

  void _onFrame(dynamic frame) {
    try {
      final j = jsonDecode(frame as String) as Map<String, dynamic>;
      switch (j['type']) {
        case 'subscribed':
          _backoff = 1;
          state = state.copyWith(live: true);
          reload(); // anything sent while we were away
        case 'message':
          final m = ChatMessage.fromJson(j['message'] as Map<String, dynamic>);
          state = state.copyWith(messages: mergeMessages(state.messages, [m]));
          _markRead();
        case 'error':
          state = state.copyWith(live: false);
      }
    } catch (e) {
      debugPrint('chat frame ignored: $e');
    }
  }

  void _lost() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _ws = null;
    state = state.copyWith(live: false);
    _retry?.cancel();
    // The token may have expired: any REST call refreshes it before we try again.
    _retry = Timer(Duration(seconds: _backoff), () async {
      await reload();
      _connect();
    });
    _backoff = (_backoff * 2).clamp(1, 30);
  }
}

final chatProvider = NotifierProvider.autoDispose.family<ChatController, ChatState, int>(ChatController.new);
