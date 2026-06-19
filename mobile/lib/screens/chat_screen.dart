import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherUserId,
    required this.otherUserName,
  });

  final int matchId;
  final int otherUserId;
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
  StreamSubscription? _typingSub;
  bool _sending = false;
  bool _otherTyping = false;
  Timer? _typingClearTimer;

  @override
  void initState() {
    super.initState();
    RealtimeService.instance.setOpenMatch(widget.matchId);
    _init();
    _messageSub = RealtimeService.instance.onMessage.listen((data) {
      if (data['matchId'] == widget.matchId) {
        _loadMessages();
        _api.markRead(widget.matchId);
      }
    });
    _typingSub = RealtimeService.instance.onTyping.listen((data) {
      if (data['matchId'] != widget.matchId) return;
      setState(() => _otherTyping = true);
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _otherTyping = false);
      });
    });
  }

  @override
  void dispose() {
    RealtimeService.instance.setOpenMatch(null);
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _myUserId = await _api.currentUserId();
    await _loadMessages();
    await _api.markRead(widget.matchId);
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

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Block ${widget.otherUserName}?'),
        content: const Text("You won't see each other or be able to message anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.blockUser(widget.otherUserId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Report ${widget.otherUserName}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _api.reportUser(widget.otherUserId, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => value == 'block' ? _block() : _report(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
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
                  child: Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMine ? Colors.pink[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(message['body']),
                      ),
                      if (isMine)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            message['read_at'] != null ? 'Read' : 'Sent',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_otherTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Typing...', style: TextStyle(fontStyle: FontStyle.italic)),
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
                      onChanged: (_) => RealtimeService.instance.sendTyping(widget.matchId),
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
