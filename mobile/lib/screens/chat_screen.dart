import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.matchId, required this.otherUserName});

  final int matchId;
  final String otherUserName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  int? _myUserId;
  StreamSubscription? _messageSub;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    RealtimeService.instance.setOpenMatch(widget.matchId);
    _init();
    _messageSub = RealtimeService.instance.onMessage.listen((data) {
      if (data['matchId'] == widget.matchId) _loadMessages();
    });
  }

  @override
  void dispose() {
    RealtimeService.instance.setOpenMatch(null);
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _myUserId = await _api.currentUserId();
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await _api.getMessages(widget.matchId);
    if (!mounted) return;
    setState(() => _messages = messages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.sendMessage(widget.matchId, text);
      _inputController.clear();
      await _loadMessages();
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final message = _messages[i];
                final isMine = message['sender_id'] == _myUserId;
                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.pink[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message['body']),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
