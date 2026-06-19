import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'signup_bio_screen.dart';

class SignupCategoriesScreen extends StatefulWidget {
  const SignupCategoriesScreen({super.key});

  @override
  State<SignupCategoriesScreen> createState() => _SignupCategoriesScreenState();
}

class _SignupCategoriesScreenState extends State<SignupCategoriesScreen> {
  final _api = ApiService();
  final _newCategoryController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  final Set<int> _selected = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await _api.getCategories();
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _proposeCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    try {
      await _api.proposeCategory(name);
      _newCategoryController.clear();
      setState(() => _info = '"$name" was submitted for moderator review.');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _continue() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.setCategories(_selected.toList());
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupBioScreen()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What are you into?')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Pick a few interests — bikers, music genres, hobbies, anything.'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in _categories)
                            FilterChip(
                              label: Text(category['name']),
                              selected: _selected.contains(category['id']),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selected.add(category['id']);
                                  } else {
                                    _selected.remove(category['id']);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newCategoryController,
                          decoration: const InputDecoration(labelText: 'Suggest a new category'),
                        ),
                      ),
                      IconButton(onPressed: _proposeCategory, icon: const Icon(Icons.add)),
                    ],
                  ),
                  if (_info != null) Text(_info!, style: const TextStyle(color: Colors.green)),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _continue,
                    child: _submitting ? const CircularProgressIndicator() : const Text('Continue'),
                  ),
                ],
              ),
            ),
    );
  }
}
