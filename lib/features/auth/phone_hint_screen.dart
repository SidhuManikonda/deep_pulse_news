import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';

/// A standalone screen that uses Android's Phone Number Hint API
/// to let the user pick a phone number from their device.
///
/// Returns the selected phone number via Navigator.pop(context, phoneNumber).
/// Returns null if user cancels or API is not supported.
class PhoneHintScreen extends StatefulWidget {
  const PhoneHintScreen({super.key});

  @override
  State<PhoneHintScreen> createState() => _PhoneHintScreenState();
}

class _PhoneHintScreenState extends State<PhoneHintScreen> {
  bool _isLoading = false;
  String? _selectedNumber;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-trigger the hint on Android
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestPhoneHint());
    }
  }

  Future<void> _requestPhoneHint() async {
    if (!Platform.isAndroid) {
      setState(() => _error = 'Phone number hint is only supported on Android');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final smartAuth = SmartAuth();
      final result = await smartAuth.requestHint(
        isPhoneNumberIdentifierSupported: true,
      );

      if (result != null && result.id.isNotEmpty) {
        setState(() {
          _selectedNumber = result.id;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No number selected';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not get phone number';
      });
    }
  }

  void _continueWithNumber() {
    if (_selectedNumber != null) {
      Navigator.pop(context, _selectedNumber);
    }
  }

  void _skip() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.appPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  size: 40,
                  color: theme.appPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Continue with your number',
                style: TextStyle(
                  fontSize: scaledFontSize(22),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Select your mobile number to quickly get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Selected number card
              if (_selectedNumber != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.appPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.phone_rounded,
                            color: theme.appPrimary, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: scaledFontSize(12),
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedNumber!,
                              style: TextStyle(
                                fontSize: scaledFontSize(18),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _requestPhoneHint,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded,
                              size: 20, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),

              // Error / retry
              if (_error != null && _selectedNumber == null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _requestPhoneHint,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try Again'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.appPrimary,
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // Continue button
              if (_selectedNumber != null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _continueWithNumber,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.appPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue with this number',
                      style: TextStyle(
                        fontSize: scaledFontSize(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Skip
              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
