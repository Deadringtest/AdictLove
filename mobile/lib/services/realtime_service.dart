import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';
import 'notification_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _matchController = StreamController<Map<String, dynamic>>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _megaLikeController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMatch => _matchController.stream;
  Stream<Map<String, dynamic>> get onRead => _readController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onMegaLike => _megaLikeController.stream;

  int? _currentlyOpenMatchId;
  void setOpenMatch(int? matchId) => _currentlyOpenMatchId = matchId;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    _channel?.sink.close();
    final wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?token=$token'));

    _channel!.stream.listen(
      (raw) {
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>;
        switch (payload['event']) {
          case 'message':
            _messageController.add(data);
            if (data['matchId'] != _currentlyOpenMatchId) {
              NotificationService.instance.show(title: 'New message', body: data['body']);
            }
            break;
          case 'match':
            _matchController.add(data);
            NotificationService.instance.show(
              title: "It's a match!",
              body: '${data['display_name']} matched with you.',
            );
            break;
          case 'read':
            _readController.add(data);
            break;
          case 'typing':
            _typingController.add(data);
            break;
          case 'mega_like':
            _megaLikeController.add(data);
            NotificationService.instance.show(
              title: 'Mega Like!',
              body: '${data['displayName']} mega-liked you.',
            );
            break;
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  }

  void sendTyping(int matchId) {
    _channel?.sink.add(jsonEncode({'event': 'typing', 'data': {'matchId': matchId}}));
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), connect);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
