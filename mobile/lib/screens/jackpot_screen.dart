import 'package:flutter/material.dart';
import '../services/api_service.dart';

class JackpotScreen extends StatefulWidget {
  const JackpotScreen({super.key});

  @override
  State<JackpotScreen> createState() => _JackpotScreenState();
}

class _JackpotScreenState extends State<JackpotScreen> {
  final _api = ApiService();
  int _tickets = 0;
  bool _spinning = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  Future<void> _refreshTickets() async {
    final tickets = await _api.getTickets();
    setState(() => _tickets = tickets);
  }

  Future<void> _spin() async {
    setState(() {
      _spinning = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _api.spinJackpot();
      setState(() => _result = result);
      await _refreshTickets();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _spinning = false);
    }
  }

  Future<void> _likeResult() async {
    if (_result == null) return;
    final mutual = await _api.likeSpinResult(_result!['id']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mutual ? "It's a match!" : 'Liked! Waiting to see if they like you back.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jackpot')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Tickets: $_tickets', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            if (_spinning) const CircularProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_result != null) ...[
              Text(_result!['display_name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_result!['bio'] != null) Text(_result!['bio']),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _likeResult, child: const Text('Like')),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _spinning || _tickets == 0 ? null : _spin,
              child: const Text('Spin the Jackpot'),
            ),
          ],
        ),
      ),
    );
  }
}
