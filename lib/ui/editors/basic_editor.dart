import 'package:flutter/widgets.dart';

import '../../hid/vial_device.dart';

/// One tab of the main window. Editors own their state and rebuild their
/// widget tree whenever they call [notifyListeners].
abstract class BasicEditor extends ChangeNotifier {
  VialDevice? device;

  /// Tab title.
  String get label;

  /// Whether this editor applies to the current device.
  bool valid();

  Future<void> rebuild(VialDevice? device) async {
    this.device = device;
  }

  /// Click on the tab background that no child consumed.
  void onContainerClicked() {}

  /// Tab became the visible one.
  void activate() {}

  /// Tab got hidden.
  void deactivate() {}

  Widget build(BuildContext context);
}
