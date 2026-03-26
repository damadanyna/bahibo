import 'package:bahibo/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return PopupMenuButton<ThemeMode>(
          icon: const Icon(Icons.person),
          onSelected: (ThemeMode mode) {
            themeProvider.setThemeMode(mode);
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
            const PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(Icons.light_mode, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Mode clair'),
                ],
              ),
            ),
            const PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(Icons.dark_mode, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Mode sombre'),
                ],
              ),
            ),
            const PopupMenuItem<ThemeMode>(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(Icons.settings_system_daydream, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Système'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
