import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var hidPlugin: HidPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 900, height: 600)
    // The Flutter view controller applies its own 800x600 preferred size once
    // it is attached, so the initial window size is set on the next runloop.
    DispatchQueue.main.async {
      self.setContentSize(NSSize(width: 1280, height: 860))
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    hidPlugin = HidPlugin(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
