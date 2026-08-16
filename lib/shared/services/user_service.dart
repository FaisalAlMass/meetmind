import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';

/// مزوّد يدير اسم المستخدم ويحفظه على القرص.
final userNameProvider =
    NotifierProvider<UserNameNotifier, String?>(UserNameNotifier.new);

class UserNameNotifier extends Notifier<String?> {
  static const _key = 'meetmind_user_name';

  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    state = trimmed.isEmpty ? null : trimmed;
    final prefs = ref.read(sharedPreferencesProvider);
    if (trimmed.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, trimmed);
    }
  }
}