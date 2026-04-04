import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/constants.dart';

class AIConfigScreen extends StatefulWidget {
  const AIConfigScreen({super.key});

  @override
  State<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends State<AIConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Box _box;

  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    _box = await Hive.openBox(AppConstants.aiConfigBox);
    _endpointController.text = _box.get('apiEndpoint', defaultValue: '');
    _apiKeyController.text = _box.get('apiKey', defaultValue: '');
    _modelNameController.text = _box.get('modelName', defaultValue: '');
    _isEnabled = _box.get('isEnabled', defaultValue: false);
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    await _box.put('apiEndpoint', _endpointController.text);
    await _box.put('apiKey', _apiKeyController.text);
    await _box.put('modelName', _modelNameController.text);
    await _box.put('isEnabled', _isEnabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'API Endpoint',
                  hintText: 'https://api.example.com/v1/chat/completions',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter your API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelNameController,
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'e.g., gpt-4-vision-preview',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable AI Features'),
                subtitle: const Text('Allow app to use AI API'),
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveConfig,
                child: const Text('Save Configuration'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }
}
