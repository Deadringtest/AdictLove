import 'package:flutter/material.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(match['display_name']),
                        subtitle: Text(
                          match['last_message'] ?? 'Say hi!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              matchId: match['match_id'],
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
