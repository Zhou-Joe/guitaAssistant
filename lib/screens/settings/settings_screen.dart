import 'package:flutter/material.dart';
import 'ai_config_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon('smart_display'),
            title: const Text('AI Configuration'),
            subtitle: const Text('Configure multimodal API endpoint'),
            trailing: const Icon('chevron_right'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIConfigScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon('info_outline'),
            title: const Text('About'),
            subtitle: const Text('Guitar Assistant v1.0.0'),
          ),
        ],
      ),
    );
  }
}
