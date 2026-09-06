import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../providers/app_providers.dart';

// Auto-play & data saver moved to dedicated controllers — see
// lib/providers/auto_play_controller.dart and data_saver_controller.dart.

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(theme)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader('Content & Playback'),
                _card([
                  _switchTile(
                    icon: Icons.play_circle_outline_rounded,
                    iconBg: const Color(0xFFEC4899),
                    title: 'Auto-play videos',
                    subtitle: 'Play news videos automatically as you scroll',
                    value: ref.watch(autoPlayProvider).enabled,
                    onChanged: (v) =>
                        ref.read(autoPlayProvider).setEnabled(v),
                  ),
                ]),
                const SizedBox(height: 20),

                _sectionHeader('Help & Support'),
                _card([
                  _navTile(
                    icon: Icons.help_outline_rounded,
                    iconBg: const Color(0xFF4A80F0),
                    title: 'Help Center',
                    subtitle: 'Get answers to common questions',
                    onTap: () => _launchUrl('https://deeppulse.media/'),
                    showDivider: true,
                  ),
                  _navTile(
                    icon: Icons.email_outlined,
                    iconBg: const Color(0xFF28C76F),
                    title: 'Contact us',
                    subtitle: 'Get in touch with our team',
                    onTap: () => _launchUrl('mailto:support@deeppulse.media'),
                    showDivider: true,
                  ),
                  _navTile(
                    icon: Icons.star_outline_rounded,
                    iconBg: const Color(0xFFFFB400),
                    title: 'Rate Deep Pulse',
                    subtitle: 'Rate the app on the Play Store',
                    onTap: () => _launchUrl(
                      'https://play.google.com/store/apps/details?id=media.deeppulse.news',
                    ),
                    showDivider: true,
                  ),
                  _navTile(
                    icon: Icons.bug_report_outlined,
                    iconBg: const Color(0xFFE07575),
                    title: 'Report a problem',
                    subtitle: 'Let us know if something is broken',
                    onTap: () => _launchUrl(
                      'mailto:support@deeppulse.media?subject=Bug%20report',
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                _sectionHeader('Legal'),
                _card([
                  _navTile(
                    icon: Icons.privacy_tip_outlined,
                    iconBg: const Color(0xFF7B61FF),
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () => _launchUrl('https://deeppulse.media/privacy.php'),
                    showDivider: true,
                  ),
                  _navTile(
                    icon: Icons.description_outlined,
                    iconBg: const Color(0xFF0EA5E9),
                    title: 'Terms of Service',
                    subtitle: 'Rules for using Deep Pulse',
                    onTap: () => _launchUrl('https://deeppulse.media/terms.php'),
                    showDivider: true,
                  ),
                  _navTile(
                    icon: Icons.info_outline,
                    iconBg: Colors.blueGrey,
                    title: 'About',
                    subtitle: 'Version ${AppConstants.appVersion}',
                    onTap: () => _showAboutSheet(theme),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(gradient: theme.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: _decorOrb(160, Colors.white.withValues(alpha: 0.07)),
          ),
          Positioned(
            top: 60,
            left: -40,
            child: _decorOrb(110, Colors.white.withValues(alpha: 0.05)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Customise your experience',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ── Common building blocks ─────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: scaledFontSize(15),
          fontWeight: FontWeight.bold,
          color: theme.appTextPrimary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconBg, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          fontWeight: FontWeight.w600,
                          color: theme.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: theme.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right,
                        color: theme.appGrey400, size: 20),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: theme.appDivider,
          ),
      ],
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool showDivider = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg.withValues(
                    alpha: enabled ? 0.12 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? iconBg : theme.appGrey400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? theme.appTextPrimary
                            : theme.appGrey400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: scaledFontSize(12),
                        color: enabled
                            ? theme.appTextSecondary
                            : theme.appGrey400,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: theme.appPrimary,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: theme.appDivider,
          ),
      ],
    );
  }

  // ── Action handlers ────────────────────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    // Try launching directly. `canLaunchUrl` is flaky on Android 11+ when the
    // `<queries>` manifest entries aren't a perfect match — but `launchUrl`
    // itself almost always works if a browser/mail client is installed.
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _handleClearCache() async {
    // Placeholder — actual clearing should hook into your CachedImageWidget
    // or any other cache manager. For now we just show feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cache cleared'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showAboutSheet(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.appPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.newspaper,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deep Pulse News',
                      style: TextStyle(
                        fontSize: scaledFontSize(17),
                        fontWeight: FontWeight.w700,
                        color: theme.appTextPrimary,
                      ),
                    ),
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: scaledFontSize(13),
                        color: theme.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Stay updated with the latest news from your area. '
              'Deep Pulse News brings local stories, breaking updates and '
              'trending content tailored to your location.',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: theme.appTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '© 2026 Deep Pulse News',
              style: TextStyle(
                fontSize: scaledFontSize(11),
                color: theme.appTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
