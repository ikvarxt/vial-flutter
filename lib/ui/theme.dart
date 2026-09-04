import 'package:flutter/material.dart';

/// QPalette roles the reference UI reads, expressed as plain colors.
class VialPalette {
  const VialPalette({
    required this.window,
    required this.windowText,
    required this.base,
    required this.alternateBase,
    required this.toolTipBase,
    required this.toolTipText,
    required this.text,
    required this.button,
    required this.buttonText,
    required this.brightText,
    required this.link,
    required this.highlight,
    required this.highlightedText,
    required this.disabledText,
    required this.disabledLight,
  });

  final Color window;
  final Color windowText;
  final Color base;
  final Color alternateBase;
  final Color toolTipBase;
  final Color toolTipText;
  final Color text;
  final Color button;
  final Color buttonText;
  final Color brightText;
  final Color link;
  final Color highlight;
  final Color highlightedText;
  final Color disabledText;
  final Color disabledLight;

  bool get isDark => window.computeLuminance() < 0.5;
}

Color _c(String hex) {
  var h = hex.trim().substring(1);
  if (h.length == 6) h = 'ff$h';
  return Color(int.parse(h, radix: 16));
}

VialPalette _p(
  String window,
  String windowText,
  String base,
  String alternateBase,
  String toolTipBase,
  String toolTipText,
  String text,
  String button,
  String buttonText,
  String brightText,
  String link,
  String highlight,
  String highlightedText,
  String disabledText,
  String disabledLight,
) => VialPalette(
  window: _c(window),
  windowText: _c(windowText),
  base: _c(base),
  alternateBase: _c(alternateBase),
  toolTipBase: _c(toolTipBase),
  toolTipText: _c(toolTipText),
  text: _c(text),
  button: _c(button),
  buttonText: _c(buttonText),
  brightText: _c(brightText),
  link: _c(link),
  highlight: _c(highlight),
  highlightedText: _c(highlightedText),
  disabledText: _c(disabledText),
  disabledLight: _c(disabledLight),
);

final List<(String, VialPalette)> themes = [
  (
    'Light',
    _p(
      '#ffefebe7',
      '#ff000000',
      '#ffffffff',
      '#fff7f5f3',
      '#ffffffdc',
      '#ff000000',
      '#ff000000',
      '#ffefebe7',
      '#ff000000',
      '#ffffffff',
      '#ff0000ff',
      '#ff308cc6',
      '#ffffffff',
      '#ffbebebe',
      '#ffffffff',
    ),
  ),
  (
    'Dark',
    _p(
      '#353535',
      '#ffffff',
      '#232323',
      '#353535',
      '#191919',
      '#ffffff',
      '#ffffff',
      '#353535',
      '#ffffff',
      '#ff0000',
      '#f7a948',
      '#bababa',
      '#232323',
      '#808080',
      '#353535',
    ),
  ),
  (
    'Arc',
    _p(
      '#353945',
      '#d3dae3',
      '#353945',
      '#404552',
      '#4B5162',
      '#d3dae3',
      '#d3dae3',
      '#353945',
      '#d3dae3',
      '#5294e2',
      '#89b1e0',
      '#5294e2',
      '#d3dae3',
      '#d3dae3',
      '#404552',
    ),
  ),
  (
    'Nord',
    _p(
      '#2e3440',
      '#eceff4',
      '#2e3440',
      '#434c5e',
      '#4c566a',
      '#eceff4',
      '#eceff4',
      '#2e3440',
      '#eceff4',
      '#88c0d0',
      '#88c0d0',
      '#88c0d0',
      '#eceff4',
      '#eceff4',
      '#88c0d0',
    ),
  ),
  (
    'Olivia',
    _p(
      '#181818',
      '#d9d9d9',
      '#181818',
      '#2c2c2c',
      '#363636',
      '#d9d9d9',
      '#d9d9d9',
      '#181818',
      '#d9d9d9',
      '#fabcad',
      '#fabcad',
      '#fabcad',
      '#2c2c2c',
      '#d9d9d9',
      '#fabcad',
    ),
  ),
  (
    'Dracula',
    _p(
      '#282a36',
      '#f8f8f2',
      '#282a36',
      '#44475a',
      '#6272a4',
      '#f8f8f2',
      '#f8f8f2',
      '#282a36',
      '#f8f8f2',
      '#8be9fd',
      '#8be9fd',
      '#8be9fd',
      '#f8f8f2',
      '#f8f8f2',
      '#8be9fd',
    ),
  ),
  (
    'Bliss',
    _p(
      '#343434',
      '#cbc8c9',
      '#343434',
      '#3b3b3b',
      '#424242',
      '#cbc8c9',
      '#cbc8c9',
      '#343434',
      '#cbc8c9',
      '#f5d1c8',
      '#f5d1c8',
      '#f5d1c8',
      '#424242',
      '#cbc8c9',
      '#f5d1c8',
    ),
  ),
  (
    'Catppuccin Latte',
    _p(
      '#eff1f5',
      '#4c4f69',
      '#eff1f5',
      '#e6e9ef',
      '#e6e9ef',
      '#4c4f69',
      '#4c4f69',
      '#eff1f5',
      '#4c4f69',
      '#d20f39',
      '#dd7878',
      '#8839ef',
      '#dce0e8',
      '#8c8fa1',
      '#ccd0da',
    ),
  ),
  (
    'Catppuccin Frappé',
    _p(
      '#303446',
      '#c6d0f5',
      '#303446',
      '#292c3c',
      '#292c3c',
      '#c6d0f5',
      '#c6d0f5',
      '#303446',
      '#c6d0f5',
      '#e78284',
      '#eebebe',
      '#ca9ee6',
      '#232634',
      '#838ba7',
      '#414559',
    ),
  ),
  (
    'Catppuccin Macchiato',
    _p(
      '#24273a',
      '#cad3f5',
      '#24273a',
      '#1e2030',
      '#1e2030',
      '#cad3f5',
      '#cad3f5',
      '#24273a',
      '#cad3f5',
      '#f38ba8',
      '#f0c6c6',
      '#c6a0f6',
      '#181926',
      '#8087a2',
      '#363a4f',
    ),
  ),
  (
    'Catppuccin Mocha',
    _p(
      '#1e1e2e',
      '#cdd6f4',
      '#1e1e2e',
      '#181825',
      '#181825',
      '#cdd6f4',
      '#cdd6f4',
      '#1e1e2e',
      '#cdd6f4',
      '#f38ba8',
      '#f2cdcd',
      '#cba6f7',
      '#11111b',
      '#7f849c',
      '#313244',
    ),
  ),
];

/// Port of QColor.lighter(): scales HSV value; overflow bleeds into
/// saturation.
Color lighter(Color c, int factor) {
  if (factor <= 0) return c;
  if (factor < 100) return darker(c, (10000 / factor).round());
  final hsv = HSVColor.fromColor(c);
  var v = hsv.value * factor / 100;
  var s = hsv.saturation;
  if (v > 1) {
    s -= v - 1;
    if (s < 0) s = 0;
    v = 1;
  }
  return hsv.withSaturation(s).withValue(v).toColor();
}

/// Port of QColor.darker().
Color darker(Color c, int factor) {
  if (factor <= 0) return c;
  if (factor < 100) return lighter(c, (10000 / factor).round());
  final hsv = HSVColor.fromColor(c);
  return hsv.withValue(hsv.value * 100 / factor).toColor();
}

/// Holds the active theme name; "System" follows the platform brightness.
class VialTheme extends ChangeNotifier {
  VialTheme._();

  static final VialTheme instance = VialTheme._();

  String _theme = 'System';

  String get theme => _theme;

  void setTheme(String theme) {
    _theme = theme;
    notifyListeners();
  }

  static VialPalette? paletteFor(String name) {
    for (final (n, p) in themes) {
      if (n == name) return p;
    }
    return null;
  }

  VialPalette paletteOf(Brightness systemBrightness) =>
      paletteFor(_theme) ??
      (systemBrightness == Brightness.dark
          ? paletteFor('Dark')!
          : paletteFor('Light')!);

  static int maskLightFactor(String theme) => theme == 'Light' ? 103 : 150;

  ThemeData themeData(Brightness systemBrightness) {
    final p = paletteOf(systemBrightness);
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.highlight,
      onPrimary: p.highlightedText,
      secondary: p.link,
      onSecondary: p.highlightedText,
      error: p.brightText,
      onError: p.window,
      surface: p.window,
      onSurface: p.windowText,
      surfaceContainerHighest: p.alternateBase,
      outline: p.disabledText,
    );
    final typography = Typography.material2021();
    final colored = brightness == Brightness.dark
        ? typography.white
        : typography.black;
    final textTheme = Typography.englishLike2021
        .merge(colored)
        .apply(bodyColor: p.text, displayColor: p.text, fontSizeFactor: 0.93);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.window,
      canvasColor: p.window,
      cardColor: p.base,
      dialogTheme: DialogThemeData(backgroundColor: p.window),
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      extensions: [VialPaletteExtension(p)],
      tabBarTheme: TabBarThemeData(
        labelColor: p.windowText,
        unselectedLabelColor: p.disabledText,
        indicatorColor: p.highlight,
        dividerColor: p.disabledLight,
        tabAlignment: TabAlignment.start,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.toolTipBase,
          border: Border.all(color: p.disabledText),
        ),
        textStyle: TextStyle(color: p.toolTipText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.buttonText,
          backgroundColor: p.button,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          side: BorderSide(color: p.disabledText.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class VialPaletteExtension extends ThemeExtension<VialPaletteExtension> {
  const VialPaletteExtension(this.palette);

  final VialPalette palette;

  @override
  ThemeExtension<VialPaletteExtension> copyWith({VialPalette? palette}) =>
      VialPaletteExtension(palette ?? this.palette);

  @override
  ThemeExtension<VialPaletteExtension> lerp(
    covariant ThemeExtension<VialPaletteExtension>? other,
    double t,
  ) => this;
}

extension VialPaletteContext on BuildContext {
  VialPalette get palette =>
      Theme.of(this).extension<VialPaletteExtension>()!.palette;
}
