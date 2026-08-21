import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/capabilities/calendar/presentation/notification_settings_screen.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/services/cloud_auth_service.dart';
import 'package:meetmind/shared/services/notification_settings.dart';
import 'package:meetmind/shared/services/user_service.dart';
import 'package:meetmind/shared/theme/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(localeProvider);
    final userName = ref.watch(userNameProvider) ?? s.defaultUserName;
    final notifSettings = ref.watch(notificationSettingsProvider);
    final initial = userName.isNotEmpty ? userName.characters.first : s.defaultInitial;
    final languageName = locale.languageCode == 'ar' ? s.arabicName : s.englishName;

    return Scaffold(
      appBar: AppBar(title: Text(s.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة المستخدم
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.primaryContainer,
                    child: Text(initial,
                        style: TextStyle(
                            fontSize: 28, color: cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(s.meetmindUser,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: s.editNameTooltip,
                    onPressed: () => _editName(context, ref, userName, s),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // حماية المواعيد (نسخة احتياطية سحابية)
          _cloudBackupCard(theme, cs, s),
          const SizedBox(height: 16),

          // الإعدادات
          Text(s.settingsSection,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(s.darkMode),
                  subtitle: Text(isDark ? s.onLabel : s.offLabel),
                  value: isDark,
                  onChanged: (on) {
                    ref.read(themeModeProvider.notifier).setMode(
                          on ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(s.languageLabel),
                  subtitle: Text(languageName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickLanguage(context, ref, s, locale),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(s.notificationsLabel),
                  subtitle: Text(notifSettings.enabled
                      ? s.reminderSummary(notifSettings.minutesBefore)
                      : s.notifDisabledSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // عن التطبيق
          Text(s.aboutSection,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(s.appName),
                  subtitle: Text(s.appTagline),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(s.versionLabel),
                  subtitle: Text('1.0.0',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text(s.logoutLabel, style: TextStyle(color: cs.error)),
              onTap: () => _logout(context, ref, s),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Text('By M.Eng Faisal AlMass',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _cloudBackupCard(ThemeData theme, ColorScheme cs, AppStrings s) {
    final auth = CloudAuthService.instance;
    final secured = !auth.isAnonymous;

    return Card(
      color: secured ? cs.primaryContainer.withValues(alpha: 0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              secured ? Icons.cloud_done_outlined : Icons.cloud_outlined,
              color: secured ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    secured ? s.cloudBackupSecuredTitle : s.cloudBackupTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    secured
                        ? s.cloudBackupSecuredBody(auth.linkedEmail ?? '')
                        : s.cloudBackupBody,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (!secured) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _linkEmail(context, s),
                      child: Text(s.linkEmailAction),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _linkEmail(BuildContext context, AppStrings s) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.linkEmailAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: s.emailLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: s.passwordLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.save),
          ),
        ],
      ),
    );

    if (submitted != true) return;
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      return;
    }
    if (!context.mounted) return;

    try {
      await CloudAuthService.instance.linkWithEmail(
        emailController.text.trim(),
        passwordController.text,
      );
      if (!context.mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.linkEmailSuccess)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.linkEmailError)));
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref, AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.logoutConfirmTitle),
        content: Text(s.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.logoutLabel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(userNameProvider.notifier).setName('');
    }
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current, AppStrings s) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.editNameTooltip),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: s.yourNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.save),
          ),
        ],
      ),
    );

    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref.read(userNameProvider.notifier).setName(controller.text);
    }
  }

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, AppStrings s, Locale current) async {
    final notifier = ref.read(localeProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.languageLabel),
        content: RadioGroup<String>(
          groupValue: current.languageCode,
          onChanged: (code) {
            if (code != null) notifier.setLocale(Locale(code));
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'ar',
                title: Text(s.arabicName),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                value: 'en',
                title: Text(s.englishName),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
