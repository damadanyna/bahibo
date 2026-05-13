import 'package:banay/auth/otp_verification.dart';
import 'package:banay/component/ui/dinamic_icon_button.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:banay/theme/app_theme_extensions.dart';

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController countryController = TextEditingController(
    text: 'Madagascar',
  );
  final TextEditingController phoneController = TextEditingController();
  final AppAuthService _authService = AppAuthService();
  bool _isSubmitting = false;
  bool _isCheckingSimNumber = false;
  String? _simPhoneHint;

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

  String get _selectedCountryName {
    final raw = countryController.text.trim();
    return countryCodes.containsKey(raw) ? raw : 'Madagascar';
  }

  String get _selectedCountryDialCode =>
      countryCodes[_selectedCountryName] ?? '+261';

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _extractLocalDigits(String value, {String? dialCode}) {
    final dialDigits = _digitsOnly(dialCode ?? _selectedCountryDialCode);
    var digits = _digitsOnly(value);

    if (dialDigits.isNotEmpty && digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }

    return digits.replaceFirst(RegExp(r'^0+'), '');
  }

  String? _resolveCountryFromPhone(String value) {
    final digits = _digitsOnly(value);
    final entries = countryCodes.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in entries) {
      final dialDigits = _digitsOnly(entry.value);
      if (digits.startsWith(dialDigits)) {
        return entry.key;
      }
    }

    return null;
  }

  Future<String?> _requestSimPhoneHint({bool applyToInput = false}) async {
    if (_isCheckingSimNumber) {
      return _simPhoneHint;
    }

    setState(() => _isCheckingSimNumber = true);

    try {
      final hint = await SmsAutoFill().hint;

      if (!mounted || hint == null || hint.trim().isEmpty) {
        return null;
      }

      final normalizedHint = hint.trim();
      final resolvedCountry = _resolveCountryFromPhone(normalizedHint);
      final resolvedDialCode = resolvedCountry == null
          ? _selectedCountryDialCode
          : countryCodes[resolvedCountry]!;

      setState(() {
        _simPhoneHint = normalizedHint;

        if (applyToInput) {
          if (resolvedCountry != null) {
            countryController.text = resolvedCountry;
          }
          phoneController.text = _extractLocalDigits(
            normalizedHint,
            dialCode: resolvedDialCode,
          );
        }
      });

      return normalizedHint;
    } on PlatformException {
      return null;
    } finally {
      if (mounted) {
        setState(() => _isCheckingSimNumber = false);
      }
    }
  }

  Future<void> _handleUseSimNumberTap() async {
    final hint = await _requestSimPhoneHint(applyToInput: true);

    if (!mounted) {
      return;
    }

    if (hint == null || hint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce telephone ne fournit pas automatiquement le numero de la carte SIM. Vous pouvez saisir le numero manuellement.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Numero SIM detecte: $hint')));
  }

  @override
  void dispose() {
    countryController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String _buildPhoneE164() {
    final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    final normalizedLocal = digits.replaceFirst(RegExp(r'^0+'), '');
    return '$_selectedCountryDialCode$normalizedLocal';
  }

  Future<void> _showPhoneConfirmationDialog() async {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final fullPhoneNumber = _buildPhoneE164();

    if (fullPhoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selectionnez un pays et saisissez un numero valide.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Column(
          children: [
            Text(
              'Confirmer le numero',
              style: TextStyle(color: appColors.heroForeground),
            ),
            const SizedBox(height: 8),
            Text(
              fullPhoneNumber,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: appColors.heroForeground,
              ),
            ),
          ],
        ),
        content: Text(
          'Un code OTP sera envoye par SMS a ce numero.',
          style: TextStyle(color: appColors.mutedText),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Modifier'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _requestOtp(fullPhoneNumber);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestOtp(String phoneE164) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appSignature = await SmsAutoFill().getAppSignature;
      final response = await _authService.requestOtp(
        phoneE164: phoneE164,
        countryName: _selectedCountryName,
        countryDialCode: _selectedCountryDialCode,
        appSignature: appSignature,
      );

      if (!mounted) {
        return;
      }

      final debugCode = (response['debugCode'] as String?)?.trim();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            phoneE164: phoneE164,
            countryName: _selectedCountryName,
            countryDialCode: _selectedCountryDialCode,
            appSignature: appSignature,
            debugCode: debugCode,
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

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

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            alignment: Alignment.center,
            child: Text(
              'Welcome to BANAY',
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
              'BANAY need to verify your phone number',
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
                DynamicIconInput(
                  controller: countryController,
                  primary: theme.colorScheme.primary,
                  panelColor: appColors.inputFill,
                  borderColor: appColors.inputBorder,
                  hintText: 'Country',
                  textInputAction: TextInputAction.next,
                  leadingIcon: Icon(Icons.public, color: appColors.mutedText),
                  trailingIcon: PopupMenuButton<String>(
                    initialValue: _selectedCountryName,
                    tooltip: 'Choisir un pays',
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: appColors.heroForeground,
                    ),
                    onSelected: (country) {
                      setState(() {
                        countryController.text = country;
                      });
                    },
                    itemBuilder: (context) => countryCodes.keys
                        .map(
                          (country) => PopupMenuItem<String>(
                            value: country,
                            child: Text('$country (${countryCodes[country]})'),
                          ),
                        )
                        .toList(),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.inputFill,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: appColors.inputBorder),
                      ),
                      child: Text(
                        _selectedCountryDialCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: appColors.heroForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DynamicIconInput(
                        controller: phoneController,
                        primary: theme.colorScheme.primary,
                        panelColor: appColors.inputFill,
                        borderColor: appColors.inputBorder,
                        hintText: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.done,
                        leadingIcon: Icon(
                          Icons.phone,
                          color: appColors.mutedText,
                        ),
                        leadingSize: 38,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isCheckingSimNumber
                        ? null
                        : _handleUseSimNumberTap,
                    icon: Icon(
                      _isCheckingSimNumber
                          ? Icons.hourglass_top
                          : Icons.sim_card_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _isCheckingSimNumber
                          ? 'Detection...'
                          : 'Utiliser mon numero SIM',
                    ),
                  ),
                ),
                if (_simPhoneHint != null && _simPhoneHint!.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Numero detecte: $_simPhoneHint',
                      style: TextStyle(
                        fontSize: 12,
                        color: appColors.mutedText,
                      ),
                    ),
                  ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: DynamicIconButton(
                    text: _isSubmitting ? 'Sending OTP...' : 'Continue',
                    icon: Icon(
                      _isSubmitting ? Icons.hourglass_top : Icons.arrow_forward,
                      size: 20,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : _showPhoneConfirmationDialog,
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
}
