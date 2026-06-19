import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;
  StreamSubscription? _matchSub;
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    _load();
    _matchSub = RealtimeService.instance.onMatch.listen((_) => _load());
    _messageSub = RealtimeService.instance.onMessage.listen((_) => _load());
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final matches = await _api.getMatches();
    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? const Center(child: Text('No matches yet — keep spinning!'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (_, i) {
                      final match = _matches[i];
                      final photoUrl = _api.photoUrl(match['photo'] as String?);
                      final unread = (match['unread_count'] as num?)?.toInt() ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Row(
                          children: [
                            Text(match['display_name']),
                            if (match['mega_match'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          match['last_message'] ?? 'Say hi!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: unread > 0
                            ? CircleAvatar(radius: 11, child: Text('$unread', style: const TextStyle(fontSize: 11)))
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              matchId: match['match_id'],
                              otherUserId: match['user_id'],
                              otherUserName: match['display_name'],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
