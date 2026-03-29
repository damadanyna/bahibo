import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:bahibo/component/app_text_input.dart';
import 'package:bahibo/page/productList.dart';
import 'package:flutter/material.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({super.key});

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
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
                "Almost there!",
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w400),
              ),
            ),
            Container(
              alignment: Alignment.center,
              child: Text(
                "Add your name and a profile picture",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: appColors.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: MediaQuery.of(context).size.height / 4,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: appColors.inputFill,
                    child: Icon(
                      Icons.person,
                      size: 110,
                      color: appColors.heroForeground,
                    ),
                  ),
                  Positioned(
                    bottom: 170,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        // Action à effectuer lors du clic sur l'icône d'édition
                      },
                      child: Container(
                        width: 100 * 0.30,
                        height: 100 * 0.30,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: appColors.heroForeground,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: theme.colorScheme.onPrimary,
                          size: 100 * 0.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppInputContainer(
              child: TextField(
                decoration: appInputDecoration(
                  context,
                  hintText: 'Your Name',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: appInputTextStyle(context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BahiboNavigationShell(),
                    ),
                  );
                },
                style: ButtonStyle(
                  elevation: WidgetStateProperty.all(0),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        7,
                      ), // <- pas de coins arrondis
                    ),
                  ),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                ),
                child: Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
