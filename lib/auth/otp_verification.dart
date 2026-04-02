import 'dart:async';

import 'package:bahibo/auth/profileInformation.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.phoneE164,
    required this.countryName,
    required this.countryDialCode,
    this.appSignature,
    this.debugCode,
  });

  final String phoneE164;
  final String countryName;
  final String countryDialCode;
  final String? appSignature;
  final String? debugCode;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with CodeAutoFill {
  final AppAuthService _authService = AppAuthService();
  String _currentCode = '';
  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingSeconds = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    listenForCode();
  }

  @override
  void codeUpdated() {
    final nextCode = code ?? '';
    if (!mounted) {
      return;
    }

    setState(() {
      _currentCode = nextCode;
    });

    if (nextCode.length == 6) {
      _verifyOtp(nextCode);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = 45;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  Future<void> _verifyOtp([String? providedCode]) async {
    final otpCode = (providedCode ?? _currentCode).trim();

    if (_isVerifying || otpCode.length != 6) {
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _authService.verifyOtp(
        phoneE164: widget.phoneE164,
        otpCode: otpCode,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileInformationPage(
            phoneE164: widget.phoneE164,
            countryName: widget.countryName,
            countryDialCode: widget.countryDialCode,
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
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _remainingSeconds > 0) {
      return;
    }

    setState(() => _isResending = true);

    try {
      final response = await _authService.requestOtp(
        phoneE164: widget.phoneE164,
        countryName: widget.countryName,
        countryDialCode: widget.countryDialCode,
        appSignature: widget.appSignature,
      );

      if (!mounted) {
        return;
      }

      _startCountdown();

      final debugCode = response['debugCode'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debugCode == null
                ? 'Un nouveau code OTP a ete envoye.'
                : 'OTP renvoye. Code de test: $debugCode',
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
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: appColors.heroForeground,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Verify your number',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: appColors.heroForeground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to ${widget.phoneE164}. On compatible devices, the code will be detected automatically.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: appColors.mutedText,
                ),
              ),
              if (widget.appSignature == null ||
                  widget.appSignature!.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Auto-detection is unavailable on this device, but manual OTP entry still works.',
                  style: TextStyle(fontSize: 13, color: appColors.mutedText),
                ),
              ],
              if (widget.debugCode != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: appColors.inputFill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: appColors.inputBorder),
                  ),
                  child: Text(
                    'Mode dev: OTP actuel ${widget.debugCode}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: appColors.heroForeground,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: appColors.inputFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: appColors.inputBorder),
                ),
                child: PinFieldAutoFill(
                  currentCode: _currentCode,
                  codeLength: 6,
                  autoFocus: true,
                  decoration: BoxLooseDecoration(
                    strokeColorBuilder: FixedColorBuilder(
                      appColors.inputBorder,
                    ),
                    bgColorBuilder: FixedColorBuilder(appColors.backgroundBase),
                    textStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: appColors.heroForeground,
                    ),
                    radius: const Radius.circular(16),
                  ),
                  onCodeChanged: (value) {
                    final nextValue = value ?? '';
                    setState(() {
                      _currentCode = nextValue;
                    });

                    if (nextValue.length == 6) {
                      _verifyOtp(nextValue);
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _remainingSeconds > 0
                    ? 'Resend available in ${_remainingSeconds}s'
                    : 'You can request a new OTP now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: appColors.mutedText),
              ),
              const SizedBox(height: 18),
              DynamicIconButton(
                text: _isVerifying ? 'Verifying...' : 'Verify OTP',
                icon: Icon(
                  _isVerifying
                      ? Icons.verified_user_outlined
                      : Icons.check_circle_outline,
                  size: 20,
                ),
                onPressed: _isVerifying ? null : () => _verifyOtp(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_remainingSeconds == 0 && !_isResending)
                    ? _resendOtp
                    : null,
                child: Text(
                  _isResending ? 'Resending...' : 'Resend code',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: appColors.socialWhatsApp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
