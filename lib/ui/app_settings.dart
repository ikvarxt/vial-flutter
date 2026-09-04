import 'package:shared_preferences/shared_preferences.dart';

/// Persistent user preferences (the reference app used QSettings).
class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get theme => _prefs?.getString('theme') ?? 'Dark';

  set theme(String v) => _prefs?.setString('theme', v);

  String get keymap => _prefs?.getString('keymap') ?? 'QWERTY';

  set keymap(String v) => _prefs?.setString('keymap', v);
}
