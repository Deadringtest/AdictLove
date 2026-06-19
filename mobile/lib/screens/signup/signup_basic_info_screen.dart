import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'signup_email_verify_screen.dart';

class SignupBasicInfoScreen extends StatefulWidget {
  const SignupBasicInfoScreen({super.key});

  @override
  State<SignupBasicInfoScreen> createState() => _SignupBasicInfoScreenState();
}

class _SignupBasicInfoScreenState extends State<SignupBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pronounsController = TextEditingController();

  DateTime? _birthdate;
  String _gender = 'woman';
  bool _loading = false;
  String? _error;

  static const int _minAge = 18;

  bool get _isOldEnough {
    if (_birthdate == null) return false;
    final now = DateTime.now();
    int age = now.year - _birthdate!.year;
    if (now.month < _birthdate!.month ||
        (now.month == _birthdate!.month && now.day < _birthdate!.day)) {
      age--;
    }
    return age >= _minAge;
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthdate == null) {
      setState(() => _error = 'Birthdate is required');
      return;
    }
    if (!_isOldEnough) {
      setState(() => _error = 'You must be at least $_minAge years old to sign up');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        birthdate: _birthdate!.toIso8601String().split('T').first,
        gender: _gender,
        pronouns: _pronounsController.text.trim().isEmpty ? null : _pronounsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SignupEmailVerifyScreen(email: _emailController.text.trim()),
        ),
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
      appBar: AppBar(title: const Text('Create your account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_birthdate == null
                    ? 'Birthdate'
                    : 'Birthdate: ${_birthdate!.toIso8601String().split('T').first}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickBirthdate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'woman', child: Text('Woman')),
                  DropdownMenuItem(value: 'man', child: Text('Man')),
                  DropdownMenuItem(value: 'non-binary', child: Text('Non-binary')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? _gender),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pronounsController,
                decoration: const InputDecoration(labelText: 'Pronouns (optional)', hintText: 'she/her, he/him, they/them...'),
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _continue,
                child: _loading ? const CircularProgressIndicator() : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
