import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rail_aid/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            value: theme.isDark,
            onChanged: (_) => theme.toggle(),
            title: const Text('Dark theme'),
            subtitle: const Text('Toggle app theme'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(context: context, applicationName: 'RailAid (scaffold)', children: [const Text('Scaffold app for complaints')]),
          ),
        ],
      ),
    );
  }
}
