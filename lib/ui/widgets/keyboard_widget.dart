import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';

import '../../kle/kle_serial.dart';
import '../constants.dart';
import '../keycode_display.dart';
import '../theme.dart';

/// Geometry and legend state of one keycap on the canvas.
class KeyModel extends KeyLegend {
  KeyModel(this.desc, double scale, [double shiftX = 0, double shiftY = 0])
    : rotationAngle = desc.rotationAngle.toDouble(),
      has2 =
          desc.width2 != desc.width ||
          desc.height2 != desc.height ||
          desc.x2 != 0 ||
          desc.y2 != 0 {
    updatePosition(scale, shiftX, shiftY);
  }

  final KleKey desc;
  final double rotationAngle;
  final bool has2;

  bool active = false;
  bool on = false;
  bool pressed = false;

  double scale = -1;
  double shiftX = double.nan;
  double shiftY = double.nan;
  late double size;
  late double rotationX;
  late double rotationY;
  late double x, y, w, h;
  late double x2, y2, w2, h2;
  late Rect rect;
  late Rect textRect;
  late Rect rect2;
  late List<Offset> bbox;
  late List<Offset> bbox2;
  late double corner;
  late Path backgroundDrawPath;
  late Path foregroundDrawPath;
  late Path extraDrawPath;
  late Rect nonmaskRect;
  late Rect maskRect;
  late List<Offset> maskBbox;

  void updatePosition(double scale, [double shiftX = 0, double shiftY = 0]) {
    if (this.scale == scale && this.shiftX == shiftX && this.shiftY == shiftY) {
      return;
    }
    this.scale = scale;
    size = scale * (keySizeRatio + keySpacingRatio);
    final spacing = scale * keySpacingRatio;

    rotationX = size * desc.rotationX;
    rotationY = size * desc.rotationY;

    this.shiftX = shiftX;
    this.shiftY = shiftY;
    x = size * desc.x;
    y = size * desc.y;
    w = size * desc.width - spacing;
    h = size * desc.height - spacing;

    rect = Rect.fromLTWH(
      x.roundToDouble(),
      y.roundToDouble(),
      w.roundToDouble(),
      h.roundToDouble(),
    );
    textRect = Rect.fromLTWH(
      x.roundToDouble(),
      (y + size * shadowTopPadding).roundToDouble(),
      w.roundToDouble(),
      (h - size * (shadowBottomPadding + shadowTopPadding)).roundToDouble(),
    );

    x2 = x + size * desc.x2;
    y2 = y + size * desc.y2;
    w2 = size * desc.width2 - spacing;
    h2 = size * desc.height2 - spacing;
    rect2 = Rect.fromLTWH(
      x2.roundToDouble(),
      y2.roundToDouble(),
      w2.roundToDouble(),
      h2.roundToDouble(),
    );

    bbox = _calculateBbox(rect);
    bbox2 = _calculateBbox(rect2);
    corner = size * keyRoundness;
    backgroundDrawPath = calculateBackgroundDrawPath();
    foregroundDrawPath = calculateForegroundDrawPath();
    extraDrawPath = calculateExtraDrawPath();

    nonmaskRect = Rect.fromLTWH(
      x.roundToDouble(),
      (y + size * keyboardWidgetNonmaskPadding).roundToDouble(),
      w.roundToDouble(),
      (h * (1 - keyboardWidgetMaskHeight)).roundToDouble(),
    );
    maskRect = Rect.fromLTWH(
      (x + size * shadowSidePadding).roundToDouble(),
      (y + h * (1 - keyboardWidgetMaskHeight)).roundToDouble(),
      (w - 2 * size * shadowSidePadding).roundToDouble(),
      (h * keyboardWidgetMaskHeight - size * shadowBottomPadding)
          .roundToDouble(),
    );
    maskBbox = _calculateBbox(maskRect);
  }

  Offset _transform(Offset p) {
    final a = rotationAngle * math.pi / 180;
    final dx = p.dx - rotationX;
    final dy = p.dy - rotationY;
    final rx = dx * math.cos(a) - dy * math.sin(a);
    final ry = dx * math.sin(a) + dy * math.cos(a);
    return Offset(rx + rotationX + shiftX, ry + rotationY + shiftY);
  }

  List<Offset> _calculateBbox(Rect r) => [
    _transform(r.topLeft),
    _transform(r.bottomLeft),
    _transform(r.bottomRight),
    _transform(r.topRight),
  ];

  /// Bounding rect of the transformed key (both parts).
  Rect get boundingRect {
    var r = _boundsOf(bbox);
    if (has2) r = r.expandToInclude(_boundsOf(bbox2));
    return r;
  }

  static Rect _boundsOf(List<Offset> pts) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool containsPoint(Offset p) =>
      _polyContains(bbox, p) || (has2 && _polyContains(bbox2, p));

  bool maskContainsPoint(Offset p) => _polyContains(maskBbox, p);

  static bool _polyContains(List<Offset> poly, Offset p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  Path _rounded(double x, double y, double w, double h) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x.roundToDouble(),
          y.roundToDouble(),
          w.roundToDouble(),
          h.roundToDouble(),
        ),
        Radius.circular(corner),
      ),
    );

  Path calculateBackgroundDrawPath() {
    var path = _rounded(x, y, w, h);
    if (has2) {
      path = Path.combine(PathOperation.union, path, _rounded(x2, y2, w2, h2));
    }
    return path;
  }

  Path calculateForegroundDrawPath() {
    var path = _rounded(
      x + size * shadowSidePadding,
      y + size * shadowTopPadding,
      w - 2 * size * shadowSidePadding,
      h - size * (shadowBottomPadding + shadowTopPadding),
    );
    if (has2) {
      path = Path.combine(
        PathOperation.union,
        path,
        _rounded(
          x2 + size * shadowSidePadding,
          y2 + size * shadowTopPadding,
          w2 - 2 * size * shadowSidePadding,
          h2 - size * (shadowBottomPadding + shadowTopPadding),
        ),
      );
    }
    return path;
  }

  Path calculateExtraDrawPath() => Path();

  @override
  String toString() {
    final q = ['KeyboardWidget'];
    if (desc.row != null) q.add('matrix:${desc.row},${desc.col}');
    if (desc.layoutIndex != -1) {
      q.add('layout:${desc.layoutIndex},${desc.layoutOption}');
    }
    return q.join(' ');
  }
}

class EncoderModel extends KeyModel {
  EncoderModel(super.desc, super.scale, [super.shiftX, super.shiftY]);

  @override
  Path calculateBackgroundDrawPath() => Path()
    ..addOval(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        w.roundToDouble(),
        h.roundToDouble(),
      ),
    );

  @override
  Path calculateForegroundDrawPath() => Path()
    ..addOval(
      Rect.fromLTWH(
        (x + size * shadowSidePadding).roundToDouble(),
        (y + size * shadowTopPadding).roundToDouble(),
        (w - 2 * size * shadowSidePadding).roundToDouble(),
        (h - size * (shadowBottomPadding + shadowTopPadding)).roundToDouble(),
      ),
    );

  @override
  Path calculateExtraDrawPath() {
    final path = Path();
    final p = h;
    final cx = x;
    final cy = y + p / 2;
    double r(double v) => v.roundToDouble();
    if (desc.encoderDir == 0) {
      // counterclockwise - pointing down
      path.moveTo(r(cx), r(cy));
      path.lineTo(r(cx + p / 10), r(cy - p / 10));
      path.lineTo(r(cx), r(cy + p / 10));
      path.lineTo(r(cx - p / 10), r(cy - p / 10));
      path.lineTo(r(cx), r(cy));
    } else {
      // clockwise - pointing up
      path.moveTo(r(cx), r(cy));
      path.lineTo(r(cx + p / 10), r(cy + p / 10));
      path.lineTo(r(cx), r(cy - p / 10));
      path.lineTo(r(cx - p / 10), r(cy + p / 10));
      path.lineTo(r(cx), r(cy));
    }
    return path;
  }

  @override
  String toString() => 'EncoderWidget';
}

/// State of a keyboard canvas: which keys are shown for the active layout
/// options, which one is selected, and the callbacks the editors hook into.
class KeyboardWidgetController extends ChangeNotifier {
  KeyboardWidgetController({
    this.layoutChoice,
    this.padding = keyboardWidgetPadding,
  });

  /// Returns the selected option of a layout choice; null means option 0.
  int Function(int layoutIndex)? layoutChoice;

  bool enabled = true;
  double scale = 1;
  double padding;

  final List<KeyModel> commonWidgets = [];
  final List<KeyModel> widgetsForLayout = [];
  List<KeyModel> widgets = [];

  double width = 0;
  double height = 0;
  KeyModel? activeKey;
  bool activeMask = false;

  VoidCallback? onClicked;
  VoidCallback? onDeselected;
  VoidCallback? onAnykey;

  void setKeys(List<KleKey> keys, List<KleKey> encoders) {
    commonWidgets.clear();
    widgetsForLayout.clear();
    for (final k in keys) {
      _add(KeyModel(k, fontHeight));
    }
    for (final e in encoders) {
      _add(EncoderModel(e, fontHeight));
    }
    updateLayout();
  }

  void _add(KeyModel w) {
    if (w.desc.layoutIndex == -1) {
      commonWidgets.add(w);
    } else {
      widgetsForLayout.add(w);
    }
  }

  void _placeWidgets() {
    const scaleFactor = fontHeight;
    widgets = [];
    for (final w in commonWidgets) {
      w.updatePosition(scaleFactor);
      widgets.add(w);
    }

    final layoutX = <int, Map<int, double>>{};
    final layoutY = <int, Map<int, double>>{};
    for (final w in widgetsForLayout) {
      w.updatePosition(scaleFactor);
      final idx = w.desc.layoutIndex, opt = w.desc.layoutOption;
      final p = w.boundingRect.topLeft;
      final lx = layoutX.putIfAbsent(idx, () => {});
      final ly = layoutY.putIfAbsent(idx, () => {});
      lx[opt] = math.min(lx[opt] ?? 1e6, p.dx);
      ly[opt] = math.min(ly[opt] ?? 1e6, p.dy);
    }

    for (final w in widgetsForLayout) {
      final idx = w.desc.layoutIndex, opt = w.desc.layoutOption;
      final choice = layoutChoice?.call(idx) ?? 0;
      if (opt == choice) {
        final sx = (layoutX[idx]![opt] ?? 1e6) - (layoutX[idx]![0] ?? 1e6);
        final sy = (layoutY[idx]![opt] ?? 1e6) - (layoutY[idx]![0] ?? 1e6);
        w.updatePosition(scaleFactor, -sx, -sy);
        widgets.add(w);
      }
    }

    var topX = 1e6, topY = 1e6;
    for (final w in widgets) {
      if (!w.desc.decal) {
        final p = w.boundingRect.topLeft;
        topX = math.min(topX, p.dx);
        topY = math.min(topY, p.dy);
      }
    }
    if (topX == 1e6) topX = 0;
    if (topY == 1e6) topY = 0;
    for (final w in widgets) {
      w.updatePosition(
        w.scale,
        w.shiftX - topX + padding,
        w.shiftY - topY + padding,
      );
    }
  }

  /// Recomputes [widgets] for the currently active layout.
  void updateLayout() {
    _placeWidgets();
    widgets = widgets.where((w) => !w.desc.decal).toList();
    widgets.sort((a, b) {
      final c = a.y.compareTo(b.y);
      return c != 0 ? c : a.x.compareTo(b.x);
    });
    var maxW = 0.0, maxH = 0.0;
    for (final k in widgets) {
      final p = k.boundingRect.bottomRight;
      maxW = math.max(maxW, p.dx * scale);
      maxH = math.max(maxH, p.dy * scale);
    }
    width = (maxW + 2 * padding).roundToDouble();
    height = (maxH + 2 * padding).roundToDouble();
    notifyListeners();
  }

  /// Returns the key under [pos] and whether the mask part was hit.
  (KeyModel?, bool) hitTest(Offset pos) {
    final p = pos / scale;
    for (final key in widgets) {
      if (key.masked && key.maskContainsPoint(p)) return (key, true);
      if (key.containsPoint(p)) return (key, false);
    }
    return (null, false);
  }

  void handlePress(Offset pos) {
    if (!enabled) return;
    final (key, mask) = hitTest(pos);
    activeKey = key;
    activeMask = mask;
    if (activeKey != null) {
      onClicked?.call();
    } else {
      onDeselected?.call();
    }
    notifyListeners();
  }

  /// Selects next key based on their order in the keymap.
  void selectNext() {
    if (widgets.isEmpty) return;
    final looped = [...widgets, widgets[0]];
    for (var i = 0; i < looped.length - 1; i++) {
      if (looped[i] == activeKey) {
        activeKey = looped[i + 1];
        activeMask = false;
        onClicked?.call();
        notifyListeners();
        return;
      }
    }
  }

  void deselect() {
    if (activeKey != null) {
      activeKey = null;
      onDeselected?.call();
      notifyListeners();
    }
  }

  void setEnabled(bool val) {
    enabled = val;
    notifyListeners();
  }

  void setScale(double s) {
    scale = s;
    updateLayout();
  }

  /// Repaints after legends or on/pressed flags changed.
  void refresh() => notifyListeners();
}

class KeyboardWidget extends StatefulWidget {
  const KeyboardWidget({super.key, required this.controller});

  final KeyboardWidgetController controller;

  @override
  State<KeyboardWidget> createState() => _KeyboardWidgetState();
}

class _KeyboardWidgetState extends State<KeyboardWidget> {
  Offset? _hover;
  String? _tooltip;
  DateTime? _lastTap;
  KeyModel? _lastTapKey;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant KeyboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onPointerDown(PointerDownEvent ev) {
    final c = widget.controller;
    if (!c.enabled) return;
    final now = DateTime.now();
    final (key, _) = c.hitTest(ev.localPosition);
    final isDouble =
        key != null &&
        _lastTapKey == key &&
        _lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 350);
    c.handlePress(ev.localPosition);
    if (isDouble && c.activeKey != null) {
      c.onAnykey?.call();
      _lastTap = null;
      _lastTapKey = null;
    } else {
      _lastTap = now;
      _lastTapKey = key;
    }
  }

  void _onHover(PointerHoverEvent ev) {
    final (key, _) = widget.controller.hitTest(ev.localPosition);
    final tip = key?.tooltip;
    final show = tip != null && tip.isNotEmpty;
    if (show != (_tooltip != null) || (show && tip != _tooltip)) {
      setState(() {
        _tooltip = show ? tip : null;
        _hover = ev.localPosition;
      });
    } else if (show && _hover != ev.localPosition) {
      setState(() => _hover = ev.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final palette = context.palette;
    // The no-op tap recognizer claims taps on the canvas so the editor's
    // container-level "click outside to deselect" handler does not fire for
    // clicks that already landed on a key.
    final canvas = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Listener(
        onPointerDown: _onPointerDown,
        child: MouseRegion(
          onHover: _onHover,
          onExit: (_) => setState(() => _tooltip = null),
          child: CustomPaint(
            size: Size(c.width, c.height),
            painter: _KeyboardPainter(
              controller: c,
              palette: palette,
              maskLightFactor: VialTheme.maskLightFactor(
                VialTheme.instance.theme,
              ),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: c.width,
      height: c.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          canvas,
          if (_tooltip != null && _hover != null)
            Positioned(
              left: _hover!.dx + 12,
              top: _hover!.dy + 16,
              child: IgnorePointer(
                child: Material(
                  elevation: 4,
                  color: palette.toolTipBase,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      _tooltip!,
                      style: TextStyle(
                        color: palette.toolTipText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter({
    required this.controller,
    required this.palette,
    required this.maskLightFactor,
  });

  final KeyboardWidgetController controller;
  final VialPalette palette;
  final int maskLightFactor;

  static const double _fontSize = 12;

  void _drawText(
    Canvas canvas,
    Rect rect,
    String text,
    Color color,
    double fontSize,
  ) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.1),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: math.max(rect.width, 1));
    canvas.save();
    canvas.clipRect(rect.inflate(2));
    tp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      ),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final regularColor = palette.buttonText;
    final background = Paint()..color = palette.button;
    final foreground = Paint()..color = lighter(palette.button, 120);
    final mask = Paint()..color = lighter(palette.button, maskLightFactor);
    final activePen = Paint()
      ..color = palette.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final extra = Paint()..color = palette.buttonText;
    final backgroundPressed = Paint()..color = palette.highlight;
    final foregroundPressed = Paint()..color = lighter(palette.highlight, 120);
    final backgroundOn = Paint()..color = darker(palette.highlight, 150);
    final foregroundOn = Paint()..color = darker(palette.highlight, 120);
    final maskFontSize = (_fontSize * 0.8).roundToDouble();

    for (final key in controller.widgets) {
      canvas.save();
      canvas.scale(controller.scale, controller.scale);
      canvas.translate(key.shiftX, key.shiftY);
      canvas.translate(key.rotationX, key.rotationY);
      canvas.rotate(key.rotationAngle * math.pi / 180);
      canvas.translate(-key.rotationX, -key.rotationY);

      final active =
          key.active || (controller.activeKey == key && !controller.activeMask);

      var brush = background;
      if (key.pressed) {
        brush = backgroundPressed;
      } else if (key.on) {
        brush = backgroundOn;
      }
      canvas.drawPath(key.backgroundDrawPath, brush);
      if (active) canvas.drawPath(key.backgroundDrawPath, activePen);

      brush = foreground;
      if (key.pressed) {
        brush = foregroundPressed;
      } else if (key.on) {
        brush = foregroundOn;
      }
      canvas.drawPath(key.foregroundDrawPath, brush);

      if (key.masked) {
        _drawText(
          canvas,
          key.nonmaskRect,
          key.text,
          key.colorOverride ? palette.link : regularColor,
          maskFontSize,
        );
        final rr = RRect.fromRectAndRadius(
          key.maskRect,
          Radius.circular(key.corner),
        );
        canvas.drawRRect(rr, mask);
        if (controller.activeKey == key && controller.activeMask) {
          canvas.drawRRect(rr, activePen);
        }
        _drawText(
          canvas,
          key.maskRect,
          key.maskText,
          key.maskColorOverride ? palette.link : regularColor,
          maskFontSize,
        );
      } else {
        _drawText(
          canvas,
          key.textRect,
          key.text,
          key.colorOverride ? palette.link : regularColor,
          _fontSize,
        );
      }

      canvas.drawPath(key.extraDrawPath, extra);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KeyboardPainter old) => true;
}
