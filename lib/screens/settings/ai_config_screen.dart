import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:guitar_assistant/data/models/ai_config.dart';

class AIConfigScreen extends StatefulWidget {
  const AIConfigScreen({super.key});

  @override
  State<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends State<AIConfigScreen> {
  final _formKey = GlobalKey<FormState>();

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

  void _loadConfig() {
    // Box is already opened in app.dart, just get it
    final box = Hive.box<AIConfig>(AppConstants.aiConfigBox);
    final config = box.get('default', defaultValue: AIConfig());
    _endpointController.text = config?.apiEndpoint ?? '';
    _apiKeyController.text = config?.apiKey ?? '';
    _modelNameController.text = config?.modelName ?? '';
    _isEnabled = config?.isEnabled ?? false;
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final box = Hive.box<AIConfig>(AppConstants.aiConfigBox);
    final config = AIConfig(
      apiEndpoint: _endpointController.text,
      apiKey: _apiKeyController.text,
      modelName: _modelNameController.text,
      isEnabled: _isEnabled,
    );
    await box.put('default', config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configuration saved'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Configuration'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cta),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Enable Toggle Section
                  _SectionHeader(title: 'AI Features'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsToggle(
                        title: 'Enable AI Features',
                        subtitle: 'Allow app to use AI API',
                        value: _isEnabled,
                        onChanged: (value) => setState(() => _isEnabled = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // API Configuration Section
                  _SectionHeader(title: 'API Configuration'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _buildTextField(
                        controller: _endpointController,
                        label: 'API Endpoint',
                        hint: 'https://api.example.com/v1/chat/completions',
                        keyboardType: TextInputType.url,
                      ),
                      _buildDivider(),
                      _buildTextField(
                        controller: _apiKeyController,
                        label: 'API Key',
                        hint: 'Enter your API key',
                        obscureText: true,
                      ),
                      _buildDivider(),
                      _buildTextField(
                        controller: _modelNameController,
                        label: 'Model Name',
                        hint: 'e.g., gpt-4-vision-preview',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Save Button
                  ElevatedButton(
                    onPressed: _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Save Configuration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cta, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.textMuted.withValues(alpha: 0.2),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.cta.withValues(alpha: 0.5),
            activeThumbColor: AppColors.cta,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceElevated,
          ),
        ],
      ),
    );
  }
}