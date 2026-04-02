import 'dart:io';

import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({
    super.key,
    required this.phoneE164,
    required this.countryName,
    required this.countryDialCode,
  });

  final String phoneE164;
  final String countryName;
  final String countryDialCode;

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AppAuthService _authService = AppAuthService();
  File? _selectedProfileImage;
  bool _isSubmitting = false;

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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final displayName = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (displayName.length < 2 || password.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez un nom et un mot de passe de 6 caracteres.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.registerOrLogin(
        phoneE164: widget.phoneE164,
        countryName: widget.countryName,
        countryDialCode: widget.countryDialCode,
        displayName: displayName,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BahiboNavigationShell()),
      );
    } on AppApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                text: _isSubmitting ? 'Connexion...' : 'Continue',
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward, size: 20),
                onPressed: _isSubmitting ? null : _submitProfile,
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
