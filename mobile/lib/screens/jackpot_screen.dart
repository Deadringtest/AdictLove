import 'dart:async';
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

  List<Map<String, dynamic>> _reel = [];
  int _reelIndex = 0;
  Timer? _reelTimer;

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  @override
  void dispose() {
    _reelTimer?.cancel();
    super.dispose();
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
      final response = await _api.spinJackpot();
      final result = response['result'] as Map<String, dynamic>;
      final decoys = response['decoys'] as List<Map<String, dynamic>>;

      _reel = [...decoys, result];
      if (_reel.length < 2) _reel = [result, result, result];
      _reelIndex = 0;

      await _animateReel();

      setState(() => _result = result);
      await _refreshTickets();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _spinning = false);
    }
  }

  Future<void> _animateReel() {
    final completer = Completer<void>();
    int ticks = 0;
    const totalTicks = 18;
    var delay = 80;

    void tick() {
      setState(() => _reelIndex = (_reelIndex + 1) % _reel.length);
      ticks++;
      if (ticks >= totalTicks) {
        setState(() => _reelIndex = _reel.length - 1);
        completer.complete();
        return;
      }
      if (ticks > totalTicks - 6) delay += 35;
      _reelTimer = Timer(Duration(milliseconds: delay), tick);
    }

    tick();
    return completer.future;
  }

  Future<void> _likeResult() async {
    if (_result == null) return;
    final mutual = await _api.likeSpinResult(_result!['id']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mutual ? "It's a match!" : 'Liked! Waiting to see if they like you back.')),
    );
  }

  Widget _photoTile(Map<String, dynamic>? person, {double size = 160}) {
    final url = _api.photoUrl(person?['photo'] as String?);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: url != null
          ? Image.network(url, width: size, height: size, fit: BoxFit.cover)
          : Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 64),
            ),
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
            if (_spinning && _reel.isNotEmpty) _photoTile(_reel[_reelIndex]),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_spinning && _result != null) ...[
              _photoTile(_result),
              const SizedBox(height: 12),
              Text(_result!['display_name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_result!['bio'] != null && (_result!['bio'] as String).isNotEmpty) Text(_result!['bio']),
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
