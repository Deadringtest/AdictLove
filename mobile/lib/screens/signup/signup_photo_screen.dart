import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'signup_categories_screen.dart';

class SignupPhotoScreen extends StatefulWidget {
  const SignupPhotoScreen({super.key});

  @override
  State<SignupPhotoScreen> createState() => _SignupPhotoScreenState();
}

class _SignupPhotoScreenState extends State<SignupPhotoScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final List<File> _photos = [];
  bool _uploading = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  Future<void> _continue() async {
    if (_photos.isEmpty) {
      setState(() => _error = 'At least one photo is required to finish signup');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      for (final photo in _photos) {
        await _api.uploadPhoto(photo);
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupCategoriesScreen()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add photos')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('At least one photo is required to complete your profile.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(photo, width: 100, height: 100, fit: BoxFit.cover),
                  ),
                InkWell(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _uploading ? null : _continue,
              child: _uploading ? const CircularProgressIndicator() : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
