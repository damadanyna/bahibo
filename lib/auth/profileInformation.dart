import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:bahibo/component/app_text_input.dart';
import 'package:bahibo/page/productList.dart';
import 'package:flutter/material.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({super.key});

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
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
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 40),
            SizedBox(
              height: MediaQuery.of(context).size.height / 4,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.person, size: 110, color: Colors.white),
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
                          color: Colors.green, // vert WhatsApp
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
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
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainNavigationShell(
                        items: bahiboMainNavigationItems,
                        pagesBuilder: (currentIndex, items, onIndexChanged) => [
                          Productlist(
                            currentMenuIndex: currentIndex,
                            navigationItems: items,
                            onMenuSelected: onIndexChanged,
                          ),
                          const MainNavigationSettingsPanel(),
                          const MainNavigationSearchPanel(),
                          const MainNavigationCategoryHubPanel(),
                        ],
                      ),
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
