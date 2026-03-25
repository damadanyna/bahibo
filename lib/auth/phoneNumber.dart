import 'package:bahibo/auth/profileInformation.dart';
import 'package:bahibo/formatter/PhoneNumberFormatter%20extends%20TextInputFormatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            alignment: Alignment.center,
            child: Text(
              'Welcome to Bahibo',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w400),
            ),
          ),
          SizedBox(height: 10),
          Container(
            alignment: Alignment.center,
            child: Text(
              'Bahibo need to verify you phone number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
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
                color: Colors.grey,
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
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Country",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.public),
                          ),
                        );
                      },
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: phoneController,

                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                        const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
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
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.perm_contact_cal_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    SizedBox(width: 50),
                    Text(
                      "+",
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    SizedBox(width: 50),
                    Icon(Icons.folder_outlined, color: Colors.white, size: 40),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.all(12),

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
                    SizedBox(height: 10),
                    const Text(
                      "To easily send messages and photos to friends and family, "
                      "allow Bahibo to access your photos and other media.",
                      style: TextStyle(fontSize: 14, color: Colors.black),
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
                          child: const Text(
                            "Not now",
                            style: TextStyle(color: Color(0xFF25D366)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileInformationPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Continue",
                            style: TextStyle(color: Color(0xFF25D366)),
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
