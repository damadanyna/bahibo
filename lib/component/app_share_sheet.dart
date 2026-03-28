import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<void> showAppShareSheet(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111111),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final suggestions =
          <({IconData icon, String title, Color backgroundColor})>[
            (
              icon: FontAwesomeIcons.facebookF,
              title: 'Facebook',
              backgroundColor: const Color(0xFF4267B2),
            ),
            (
              icon: FontAwesomeIcons.whatsapp,
              title: 'WhatsApp',
              backgroundColor: const Color(0xFF25D366),
            ),
          ];

      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.34,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: suggestions
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${item.title} indisponible pour le moment',
                                    ),
                                  ),
                                );
                              },
                              customBorder: const CircleBorder(),
                              child: Ink(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: item.backgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
