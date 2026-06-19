import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'signup_photo_screen.dart';

class SignupEmailVerifyScreen extends StatefulWidget {
  const SignupEmailVerifyScreen({super.key, required this.email});

  final String email;

  @override
  State<SignupEmailVerifyScreen> createState() => _SignupEmailVerifyScreenState();
}

class _SignupEmailVerifyScreenState extends State<SignupEmailVerifyScreen> {
  final _codeController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _info;

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.verifyEmail(email: widget.email, code: _codeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupPhotoScreen()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _info = null;
    });
    try {
      await _api.resendVerification(email: widget.email);
      setState(() => _info = 'A new code was sent to ${widget.email}');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('We sent a 6-digit code to ${widget.email}'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_info != null) Text(_info!, style: const TextStyle(color: Colors.green)),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading ? const CircularProgressIndicator() : const Text('Verify'),
            ),
            TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(_resending ? 'Sending...' : 'Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
