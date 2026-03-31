import 'dart:io';

import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({super.key});

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  File? _selectedProfileImage;

  Future<void> _pickProfileImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() {
      _selectedProfileImage = File(file.path);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final avatarSectionHeight = (screenHeight * 0.24).clamp(170.0, 250.0);
    final avatarRadius = (screenHeight * 0.075).clamp(58.0, 76.0);
    final actionButtonSize = avatarRadius * 0.48;

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
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w400,
                  color: appColors.heroForeground,
                ),
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
              height: avatarSectionHeight,
              child: Center(
                child: SizedBox(
                  width: avatarRadius * 2 + actionButtonSize * 0.9,
                  height: avatarRadius * 2 + actionButtonSize * 0.9,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: appColors.inputFill,
                        backgroundImage: _selectedProfileImage != null
                            ? FileImage(_selectedProfileImage!)
                            : null,
                        child: _selectedProfileImage == null
                            ? Icon(
                                Icons.person,
                                size: avatarRadius * 1.8,
                                color: appColors.heroForeground,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            width: actionButtonSize,
                            height: actionButtonSize,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: appColors.heroForeground,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              color: theme.colorScheme.onPrimary,
                              size: actionButtonSize * 0.72,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DynamicIconInput(
              controller: _nameController,
              primary: theme.colorScheme.primary,
              panelColor: appColors.inputFill,
              borderColor: appColors.inputBorder,
              hintText: 'Your Name',
              leadingIcon: Icon(
                Icons.person_outline,
                color: appColors.mutedText,
              ),
              leadingSize: 38,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: DynamicIconButton(
                text: 'Continue',
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BahiboNavigationShell(),
                    ),
                  );
                },
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
