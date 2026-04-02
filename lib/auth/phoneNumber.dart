import 'package:bahibo/auth/profileInformation.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/formatter/PhoneNumberFormatter%20extends%20TextInputFormatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController phoneController = TextEditingController();

  final Map<String, String> countryCodes = {
    "Madagascar": "+261",
    "France": "+33",
    "Mauritius": "+230",
    "Canada": "+1",
    "Germany": "+49",
    "Italy": "+39",
    "Spain": "+34",
    "United States": "+1",
    "China": "+86",
    "Japan": "+81",
    "India": "+91",
  };

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    return compact.startsWith('+') ? compact : '+$compact';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            alignment: Alignment.center,
            child: Text(
              'Welcome to Bahibo',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w400,
                color: appColors.heroForeground,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            alignment: Alignment.center,
            child: Text(
              'Bahibo need to verify you phone number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: appColors.mutedText,
              ),
            ),
          ),
          Container(
            alignment: Alignment.center,
            child: Text(
              'to connect in your account',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: appColors.mutedText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }

                    const countries = [
                      "Madagascar",
                      "France",
                      "Mauritius",
                      "Canada",
                      "Germany",
                      "Italy",
                      "Spain",
                      "United States",
                      "China",
                      "Japan",
                      "India",
                    ];

                    return countries.where((country) {
                      return country.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },

                  onSelected: (String country) {
                    phoneController.text = countryCodes[country]! + " ";
                  },

                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                        return DynamicIconInput(
                          controller: controller,
                          focusNode: focusNode,
                          primary: theme.colorScheme.primary,
                          panelColor: appColors.inputFill,
                          borderColor: appColors.inputBorder,
                          hintText: 'Country',
                          textInputAction: TextInputAction.next,
                          leadingIcon: Icon(
                            Icons.public,
                            color: appColors.mutedText,
                          ),
                          leadingSize: 38,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        );
                      },
                ),

                const SizedBox(height: 20),

                DynamicIconInput(
                  controller: phoneController,
                  primary: theme.colorScheme.primary,
                  panelColor: appColors.inputFill,
                  borderColor: appColors.inputBorder,
                  hintText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                  textInputAction: TextInputAction.done,
                  leadingIcon: Icon(Icons.phone, color: appColors.mutedText),
                  leadingSize: 38,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: DynamicIconButton(
                    text: 'Continue',
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: () {
                      String phoneNumber = phoneController.text;
                      // Affiche le dialog quand on appuie
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const Text(
                                "Is the correct phone number?",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                phoneNumber,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // ferme le dialog
                                // Ici tu peux gérer le "Don't allow"
                                print("Permission denied");
                              },
                              child: const Text("Modify"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // ferme le dialog
                                // Ici tu peux gérer le "Allow"
                                _showContactsAndMediaDialog(context);
                              },
                              child: const Text("Yes"),
                            ),
                          ],
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
        ],
      ),
    );
  }

  void _showContactsAndMediaDialog(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône verte en haut
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: appColors.socialWhatsApp,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.perm_contact_cal_outlined,
                      color: appColors.heroForeground,
                      size: 40,
                    ),
                    const SizedBox(width: 50),
                    Text(
                      "+",
                      style: TextStyle(
                        color: appColors.heroForeground,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 50),
                    Icon(
                      Icons.folder_outlined,
                      color: appColors.heroForeground,
                      size: 40,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(12),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      child: // Titre
                      const Text(
                        "Contacts and media",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "To easily send messages and photos to friends and family, "
                      "allow Bahibo to access your photos and other media.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            print("Not now tapped");
                          },
                          child: Text(
                            "Not now",
                            style: TextStyle(color: appColors.socialWhatsApp),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileInformationPage(
                                  phoneE164: _normalizePhoneNumber(
                                    phoneController.text,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            "Continue",
                            style: TextStyle(color: appColors.socialWhatsApp),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
