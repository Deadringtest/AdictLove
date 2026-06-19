import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../jackpot_screen.dart';

class SignupBioScreen extends StatefulWidget {
  const SignupBioScreen({super.key});

  @override
  State<SignupBioScreen> createState() => _SignupBioScreenState();
}

class _SignupBioScreenState extends State<SignupBioScreen> {
  final _bioController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String? _error;

  Future<void> _finish() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.updateProfile(bio: _bioController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const JackpotScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Write a short intro or go as long as you like. You can edit this later.'),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _finish,
              child: _loading ? const CircularProgressIndicator() : const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}
