import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debug/ui_probe.dart';
import 'protocol/keyboard.dart';
import 'settings/qmk_settings.dart';
import 'ui/app_globals.dart';
import 'ui/app_settings.dart';
import 'ui/dialogs/unlocker_dialog.dart';
import 'ui/main_window.dart';
import 'ui/theme.dart';

bool _reportingError = false;

void _reportError(Object error, StackTrace? stack) {
  if (_reportingError) return;
  if (rootNavigatorKey.currentContext == null) return;
  _reportingError = true;
  showWarning('$error\n\n${stack ?? ''}', title: 'Vial').whenComplete(() {
    _reportingError = false;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  QmkSettings.initialize();
  ensureKeycodesInitialized();
  Keyboard.unlocker = Unlocker.unlock;
  await AppSettings.instance.load();
  VialTheme.instance.setTheme(AppSettings.instance.theme);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportError(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportError(error, stack);
    return true;
  };

  UiProbe.register();
  runZonedGuarded(() => runApp(const VialApp()), _reportError);
}

class VialApp extends StatelessWidget {
  const VialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VialTheme.instance,
      builder: (context, _) => MaterialApp(
        title: 'Vial',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: VialTheme.instance.themeData(Brightness.light),
        darkTheme: VialTheme.instance.themeData(Brightness.dark),
        home: const MainWindow(),
        builder: (context, child) => UiProbe.wrap(child!),
      ),
    );
  }
}
