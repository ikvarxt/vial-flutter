import 'package:flutter/material.dart';

/// Navigator used by non-widget code (tray targets, unlocker) to show dialogs.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

BuildContext get rootContext => rootNavigatorKey.currentContext!;

/// Counting lock mirroring `MainWindow.lock_ui()/unlock_ui()`: while locked
/// the device selector, tabs and autorefresh are disabled.
class UiLock extends ChangeNotifier {
  UiLock._();

  static final UiLock instance = UiLock._();

  int _count = 0;

  bool get locked => _count > 0;

  void lock() {
    _count++;
    notifyListeners();
  }

  void unlock() {
    _count--;
    notifyListeners();
  }
}

Future<void> showWarning(String message, {String title = 'Vial'}) async {
  await showDialog<void>(
    context: rootContext,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SelectableText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool> showQuestion(String message, {String title = 'Vial'}) async {
  final r = await showDialog<bool>(
    context: rootContext,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return r ?? false;
}
