import 'package:flutter/material.dart';
import 'phoneNumber.dart';

import 'package:banay/theme/app_theme_extensions.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String? _selectedLanguage = 'Malagasy';

  // Liste dynamique des langues
  final List<Map<String, String>> languages = [
    {'name': 'Malagasy', 'native': 'Malagasy', 'isSelect': 'true'},
    {'name': 'English', 'native': 'English', 'isSelect': 'false'},
    {'name': 'French', 'native': 'Français', 'isSelect': 'false'},
    {'name': 'Mandarin Chinese', 'native': '中文', 'isSelect': 'false'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'isSelect': 'false'},
    {'name': 'Spanish', 'native': 'Español', 'isSelect': 'false'},
    {'name': 'Arabic', 'native': 'العربية', 'isSelect': 'false'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      resizeToAvoidBottomInset: false,

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              alignment: Alignment.center,
              child: Text(
                "Akory, tonga soa ato @ BANAY",
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w400),
              ),
            ),
            Container(
              alignment: Alignment.center,
              child: Text(
                "Safidio ny fiteninao hanombohana",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: appColors.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height / 2,
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return RadioListTile<String>(
                    activeColor: theme.colorScheme.primary,
                    tileColor: appColors.backgroundBase,
                    selectedTileColor: appColors.backgroundBase,
                    title: Text(
                      language['name']!,
                      style: TextStyle(color: appColors.heroForeground),
                    ),
                    // ignore: deprecated_member_use
                    groupValue: _selectedLanguage,
                    subtitle: Text(
                      language['native']!,
                      style: TextStyle(color: appColors.mutedText),
                    ),
                    value: language['name']!,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value;
                        for (var lang in languages) {
                          lang['isSelect'] = (lang['name'] == value).toString();
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        elevation: 0,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PhoneNumberPage()),
          );
        },
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
