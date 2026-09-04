import 'package:flutter/material.dart';

/// Named corner radii shared by every surface in the app.
abstract final class VialRadius {
  static const double keycap = 5;
  static const double control = 6;
  static const double panel = 10;
}

/// QPalette roles the reference UI reads, expressed as plain colors, plus the
/// surfaces derived from them so all bundled themes get the same rendering.
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

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Main working area behind the keyboard.
  Color get canvas => window;

  /// Top bar and dialogs: one step lighter than the canvas.
  Color get bar => isDark
      ? _mix(window, Colors.white, 0.04)
      : _mix(window, Colors.white, 0.7);

  /// Keycode picker tray: one step darker than the canvas.
  Color get tray => isDark
      ? _mix(window, Colors.black, 0.22)
      : _mix(window, Colors.black, 0.025);

  /// Hairline used for every divider and control outline.
  Color get hairline => isDark
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.black.withValues(alpha: 0.10);

  Color get ink => windowText;

  Color get muted => _mix(windowText, window, 0.5);

  Color get accent => highlight;

  Color get onAccent => highlightedText;

  /// Subtle hover wash for flat controls.
  Color get hover => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.05);

  /// Keycap faces.
  Color get keyTop => isDark
      ? _mix(button, Colors.white, 0.10)
      : _mix(button, Colors.white, 0.85);

  Color get keySide => isDark
      ? _mix(button, Colors.black, 0.35)
      : _mix(button, Colors.black, 0.16);

  Color get keyMask => isDark
      ? _mix(keyTop, Colors.white, 0.08)
      : _mix(keyTop, Colors.black, 0.05);

  Color get keyLegend => buttonText;

  Color get keyShadow => Colors.black.withValues(alpha: isDark ? 0.5 : 0.14);
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
      '#eeeeec',
      '#1b1b1a',
      '#ffffff',
      '#f6f6f4',
      '#1f1f1e',
      '#f4f4f2',
      '#1b1b1a',
      '#f4f4f2',
      '#1b1b1a',
      '#c0392b',
      '#0b6e99',
      '#e3a800',
      '#1c1500',
      '#9b9b97',
      '#dededa',
    ),
  ),
  (
    'Dark',
    _p(
      '#16171a',
      '#ececea',
      '#24262a',
      '#1c1d20',
      '#ececea',
      '#16171a',
      '#ececea',
      '#262931',
      '#ececea',
      '#f0665a',
      '#7cc0e4',
      '#f2c230',
      '#1c1500',
      '#7d8087',
      '#2c2f35',
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

const String uiFontFamily = 'IBM Plex Sans';
const String monoFontFamily = 'IBM Plex Mono';

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

  ThemeData themeData(Brightness systemBrightness) {
    final p = paletteOf(systemBrightness);
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.canvas,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: p.brightText,
      onError: p.canvas,
      surface: p.canvas,
      onSurface: p.ink,
      surfaceContainerHighest: p.alternateBase,
      surfaceContainerLow: p.bar,
      outline: p.hairline,
      outlineVariant: p.hairline,
      onSurfaceVariant: p.muted,
    );
    TextStyle t(
      double size, {
      FontWeight weight = FontWeight.w400,
      double? height,
      Color? color,
    }) => TextStyle(
      fontFamily: uiFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height ?? 1.35,
      color: color ?? p.text,
    );
    final textTheme = TextTheme(
      displayLarge: t(28, weight: FontWeight.w600, height: 1.2),
      displayMedium: t(24, weight: FontWeight.w600, height: 1.2),
      displaySmall: t(20, weight: FontWeight.w600, height: 1.25),
      headlineLarge: t(20, weight: FontWeight.w600, height: 1.25),
      headlineMedium: t(18, weight: FontWeight.w600, height: 1.25),
      headlineSmall: t(16, weight: FontWeight.w600, height: 1.3),
      titleLarge: t(16, weight: FontWeight.w600, height: 1.3),
      titleMedium: t(14, weight: FontWeight.w600),
      titleSmall: t(13, weight: FontWeight.w500),
      bodyLarge: t(14),
      bodyMedium: t(13),
      bodySmall: t(12, color: p.muted),
      labelLarge: t(13, weight: FontWeight.w500),
      labelMedium: t(12, weight: FontWeight.w500),
      labelSmall: t(11, weight: FontWeight.w500, color: p.muted),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VialRadius.control),
    );
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 12);
    const buttonSize = Size(0, 30);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: uiFontFamily,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.bar,
      cardColor: p.bar,
      dividerColor: p.hairline,
      hoverColor: p.hover,
      focusColor: p.accent.withValues(alpha: 0.35),
      highlightColor: p.hover,
      splashFactory: NoSplash.splashFactory,
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      extensions: [VialPaletteExtension(p)],
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bar,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bar,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.6 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VialRadius.panel),
          side: BorderSide(color: p.hairline),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.muted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.ink, width: 2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        dividerColor: p.hairline,
        dividerHeight: 1,
        tabAlignment: TabAlignment.start,
        overlayColor: WidgetStatePropertyAll(p.hover),
        splashFactory: NoSplash.splashFactory,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.base,
        hoverColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        hintStyle: textTheme.bodyMedium!.copyWith(color: p.muted),
        labelStyle: textTheme.bodyMedium!.copyWith(color: p.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
          borderSide: BorderSide(color: p.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
          borderSide: BorderSide(color: p.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
          borderSide: BorderSide(color: p.brightText),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
          borderSide: BorderSide(color: p.brightText, width: 1.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: p.toolTipBase,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.bodySmall!.copyWith(color: p.toolTipText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.canvas,
          disabledBackgroundColor: p.disabledLight,
          disabledForegroundColor: p.disabledText,
          padding: buttonPadding,
          minimumSize: buttonSize,
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              backgroundColor: p.base,
              disabledForegroundColor: p.disabledText,
              padding: buttonPadding,
              minimumSize: buttonSize,
              textStyle: textTheme.labelLarge,
              shape: controlShape,
              side: BorderSide(color: p.hairline),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.hovered)
                    ? Color.alphaBlend(p.hover, p.base)
                    : p.base,
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          disabledForegroundColor: p.disabledText,
          padding: buttonPadding,
          minimumSize: buttonSize,
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.ink,
          disabledForegroundColor: p.disabledText,
          hoverColor: p.hover,
          shape: controlShape,
          minimumSize: const Size(30, 30),
          iconSize: 18,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: p.muted, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.canvas),
        overlayColor: WidgetStatePropertyAll(p.hover),
        splashRadius: 0,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
        overlayColor: WidgetStatePropertyAll(p.hover),
        splashRadius: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.canvas : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.base,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.hairline,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.ink,
        inactiveTrackColor: p.hairline,
        thumbColor: p.ink,
        overlayColor: p.hover,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        valueIndicatorColor: p.toolTipBase,
        valueIndicatorTextStyle: textTheme.bodySmall!.copyWith(
          color: p.toolTipText,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.bar,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.6 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: p.hairline),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.bar),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: p.isDark ? 0.6 : 0.16),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: p.hairline),
            ),
          ),
        ),
      ),
      menuBarTheme: MenuBarThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.disabledText : p.ink,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
                ? p.hover
                : Colors.transparent,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: textTheme.bodyMedium),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(p.muted.withValues(alpha: 0.45)),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.toolTipBase,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: p.toolTipText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VialRadius.control),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.ink,
        linearTrackColor: p.hairline,
        circularTrackColor: p.hairline,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: p.muted,
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
