import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Preferences'),
            Tab(text: 'Appearance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProfileTab(),
          _PreferencesTab(),
          _AppearanceTab(),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _api = ApiService();
  final _bioController = TextEditingController();
  final _pronounsController = TextEditingController();
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _allCategories = [];
  Set<int> _selectedCategoryIds = {};
  String _verificationStatus = 'none';
  bool _loading = true;
  bool _saving = false;
  String? _message;

  List<Map<String, dynamic>> _allPrompts = [];
  final List<TextEditingController> _promptAnswerControllers =
      List.generate(3, (_) => TextEditingController());
  final List<int?> _selectedPromptIds = [null, null, null];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _promptAnswerControllers) {
      controller.dispose();
    }
    _bioController.dispose();
    _pronounsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _api.getProfile();
    final categories = await _api.getCategories();
    final allPrompts = await _api.getPrompts();
    setState(() {
      _bioController.text = profile['bio'] ?? '';
      _pronounsController.text = profile['pronouns'] ?? '';
      _photos = (profile['photos'] as List).cast<Map<String, dynamic>>();
      _allCategories = categories;
      _allPrompts = allPrompts;
      _selectedCategoryIds = (profile['categories'] as List)
          .map((c) => c['id'] as int)
          .toSet();
      _verificationStatus = profile['verification_status'] ?? 'none';

      final myPrompts = (profile['prompts'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < myPrompts.length && i < 3; i++) {
        _selectedPromptIds[i] = myPrompts[i]['prompt_id'] as int;
        _promptAnswerControllers[i].text = myPrompts[i]['answer'] as String;
      }
      _loading = false;
    });
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _api.uploadPhoto(File(picked.path));
    await _load();
  }

  Future<void> _submitVerification() async {
    final pose = await _api.getVerificationPose();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verification pose'),
        content: Text('Take a selfie while you: $pose'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Take photo')),
        ],
      ),
    );
    if (confirmed != true) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;
    await _api.uploadVerificationPhoto(File(picked.path));
    await _load();
  }

  Future<void> _deletePhoto(int id) async {
    await _api.deletePhoto(id);
    await _load();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _api.updateProfile(bio: _bioController.text.trim(), pronouns: _pronounsController.text.trim());
      await _api.setCategories(_selectedCategoryIds.toList());
      final answers = <Map<String, dynamic>>[];
      for (var i = 0; i < 3; i++) {
        if (_selectedPromptIds[i] != null && _promptAnswerControllers[i].text.trim().isNotEmpty) {
          answers.add({'promptId': _selectedPromptIds[i], 'answer': _promptAnswerControllers[i].text.trim()});
        }
      }
      await _api.setPromptAnswers(answers);
      setState(() => _message = 'Saved!');
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Photos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in _photos)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _api.photoUrl(photo['file_path']) ?? '',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(photo['id']),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            GestureDetector(
              onTap: _addPhoto,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300],
                ),
                child: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _bioController,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pronounsController,
          decoration: const InputDecoration(labelText: 'Pronouns', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        Text('Icebreaker prompts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedPromptIds[i],
                  decoration: InputDecoration(labelText: 'Prompt ${i + 1}', border: const OutlineInputBorder()),
                  items: [
                    for (final prompt in _allPrompts)
                      DropdownMenuItem(value: prompt['id'] as int, child: Text(prompt['text'])),
                  ],
                  onChanged: (value) => setState(() => _selectedPromptIds[i] = value),
                ),
                if (_selectedPromptIds[i] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _promptAnswerControllers[i],
                      decoration: const InputDecoration(labelText: 'Your answer', border: OutlineInputBorder()),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Interests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _allCategories)
              FilterChip(
                label: Text(category['name']),
                selected: _selectedCategoryIds.contains(category['id']),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategoryIds.add(category['id']);
                    } else {
                      _selectedCategoryIds.remove(category['id']);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Verification', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _verificationStatus == 'approved' ? Icons.verified : Icons.shield_outlined,
              color: _verificationStatus == 'approved' ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Status: $_verificationStatus')),
            if (_verificationStatus == 'none' || _verificationStatus == 'rejected')
              TextButton(onPressed: _submitVerification, child: const Text('Verify with selfie')),
          ],
        ),
        const SizedBox(height: 24),
        if (_message != null) Text(_message!),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const CircularProgressIndicator() : const Text('Save profile'),
        ),
      ],
    );
  }
}

class _PreferencesTab extends StatefulWidget {
  const _PreferencesTab();

  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<_PreferencesTab> {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  String? _message;

  String _interestedIn = 'everyone';
  String _lookingFor = 'unsure';
  RangeValues _ageRange = const RangeValues(18, 99);
  double _maxDistanceKm = 50;

  static const _interestedInOptions = ['everyone', 'men', 'women'];
  static const _lookingForOptions = ['unsure', 'casual', 'serious', 'friends'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _api.getPreferences();
    if (prefs != null) {
      setState(() {
        _interestedIn = prefs['interested_in'] ?? 'everyone';
        _lookingFor = prefs['looking_for'] ?? 'unsure';
        _ageRange = RangeValues(
          (prefs['min_age'] ?? 18).toDouble(),
          (prefs['max_age'] ?? 99).toDouble(),
        );
        _maxDistanceKm = (prefs['max_distance_km'] ?? 50).toDouble();
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _api.updatePreferences(
        interestedIn: _interestedIn,
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        maxDistanceKm: _maxDistanceKm.round(),
        lookingFor: _lookingFor,
      );
      setState(() => _message = 'Saved!');
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Interested in', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: [
            for (final option in _interestedInOptions)
              ChoiceChip(
                label: Text(option),
                selected: _interestedIn == option,
                onSelected: (_) => setState(() => _interestedIn = option),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Looking for', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: [
            for (final option in _lookingForOptions)
              ChoiceChip(
                label: Text(option),
                selected: _lookingFor == option,
                onSelected: (_) => setState(() => _lookingFor = option),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Age range: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        RangeSlider(
          min: 18,
          max: 99,
          values: _ageRange,
          labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
          onChanged: (values) => setState(() => _ageRange = values),
        ),
        const SizedBox(height: 16),
        Text('Max distance: ${_maxDistanceKm.round()} km', style: Theme.of(context).textTheme.titleMedium),
        Slider(
          min: 1,
          max: 200,
          value: _maxDistanceKm,
          label: '${_maxDistanceKm.round()} km',
          onChanged: (value) => setState(() => _maxDistanceKm = value),
        ),
        const SizedBox(height: 8),
        const Text(
          'Note: the jackpot spin also weights candidates toward shared interests/categories '
          "you've selected in your profile — it's still luck, just better odds with people who like what you like.",
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),
        if (_message != null) Text(_message!),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const CircularProgressIndicator() : const Text('Save preferences'),
        ),
      ],
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  static const _colorOptions = [
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.teal,
    Colors.orange,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ThemeService.instance.mode, ThemeService.instance.seedColor]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            RadioListTile<ThemeMode>(
              title: const Text('System default'),
              value: ThemeMode.system,
              groupValue: ThemeService.instance.mode.value,
              onChanged: (value) => ThemeService.instance.setMode(value!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: ThemeService.instance.mode.value,
              onChanged: (value) => ThemeService.instance.setMode(value!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: ThemeService.instance.mode.value,
              onChanged: (value) => ThemeService.instance.setMode(value!),
            ),
            const SizedBox(height: 24),
            Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                for (final color in _colorOptions)
                  GestureDetector(
                    onTap: () => ThemeService.instance.setSeedColor(color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 20,
                      child: ThemeService.instance.seedColor.value.value == color.value
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
