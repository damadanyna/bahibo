import 'package:flutter/material.dart';
import 'phoneNumber.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  String? _selectedLanguage = 'English';

  // Liste dynamique des langues
  final List<Map<String, String>> languages = [
    {'name': 'English', 'native': "device's language", 'isSelect': 'true'},
    {'name': 'French', 'native': 'Français', 'isSelect': 'false'},
    {'name': 'Malagasy', 'native': 'Malagasy', 'isSelect': 'false'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'isSelect': 'false'},
    {'name': 'Marathi', 'native': 'मराठी', 'isSelect': 'false'},
    {'name': 'Gujarati', 'native': 'ગુજરાતી', 'isSelect': 'false'},
    {'name': 'Tamil', 'native': 'தமிழ்', 'isSelect': 'false'},
    {'name': 'Bengali', 'native': 'বাংলা', 'isSelect': 'false'},
    {'name': 'Telugu', 'native': 'తెలుగు', 'isSelect': 'false'},
    // Ajoute d'autres langues ici
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              alignment: Alignment.center,
              child: Text(
                "Hello, welcome to Bahibo",
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w400),
              ),
            ),
            Container(
              alignment: Alignment.center,
              child: Text(
                "Choose your language to get started",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height / 2,
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return RadioListTile<String>(
                    title: Text(language['name']!),
                    // ignore: deprecated_member_use
                    groupValue: _selectedLanguage,
                    subtitle: Text(language['native']!),
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
            MaterialPageRoute(builder: (context) => PhoneNumberPage()),
          );
        },
        child: Icon(Icons.arrow_forward),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
