// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../hid/vial_device.dart';
import '../ui/autorefresh.dart';

/// Debug-only VM service extensions used to drive and screenshot the app
/// from the command line on platforms where no native automation is available
/// (`ext.vial.screenshot`, `ext.vial.tap`, `ext.vial.text`, `ext.vial.dump`,
/// `ext.vial.frames`).
class UiProbe {
  UiProbe._();

  static final GlobalKey boundaryKey = GlobalKey();
  static bool _registered = false;

  static Widget wrap(Widget child) =>
      RepaintBoundary(key: boundaryKey, child: child);

  /// Gaps between consecutive vsyncs, in microseconds; a long gap means the
  /// UI thread was not producing frames.
  static final List<int> _frameGaps = [];
  static int? _lastVsync;

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final v = t.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      if (_lastVsync != null) _frameGaps.add(v - _lastVsync!);
      _lastVsync = v;
    }
  }

  static void register() {
    if (!kDebugMode || _registered) return;
    _registered = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);

    developer.registerExtension('ext.vial.frames', (method, params) async {
      final threshold = int.tryParse(params['thresholdMs'] ?? '') ?? 50;
      final gaps = List<int>.of(_frameGaps);
      if (params['reset'] == 'true') {
        _frameGaps.clear();
        _lastVsync = null;
      }
      final long = gaps.where((g) => g >= threshold * 1000).toList();
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'type': 'Frames',
          'frames': gaps.length,
          'maxGapMs': gaps.isEmpty ? 0 : gaps.reduce(max) / 1000,
          'longGapsMs': [for (final g in long) g / 1000],
        }),
      );
    });

    developer.registerExtension('ext.vial.dump', (method, params) async {
      final dev = Autorefresh.instance.currentDevice;
      final kb = dev is VialKeyboard ? dev.keyboard : null;
      if (kb == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'no keyboard',
        );
      }
      String pos((int, int, int) k) => '${k.$1},${k.$2},${k.$3}';
      // Macros are deliberately left out: they may hold typed secrets.
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'type': 'Dump',
          'title': dev!.title,
          'keyboardId': kb.keyboardId.toString(),
          'viaProtocol': kb.viaProtocol,
          'vialProtocol': kb.vialProtocol,
          'layers': kb.layers,
          'rows': kb.rows,
          'cols': kb.cols,
          'layoutOptions': kb.layoutOptions,
          'layout': {for (final e in kb.layout.entries) pos(e.key): e.value},
          'encoderLayout': {
            for (final e in kb.encoderLayout.entries) pos(e.key): e.value,
          },
          'macroCount': kb.macroCount,
          'tapDance': [for (final e in kb.tapDanceEntries) '$e'],
          'combo': [for (final e in kb.comboEntries) '$e'],
          'keyOverrideCount': kb.keyOverrideEntries.length,
          'altRepeatKeyCount': kb.altRepeatKeyEntries.length,
          'settings': {
            for (final e in kb.settings.entries) '${e.key}': e.value,
          },
          'supportedSettings': kb.supportedSettings.toList()..sort(),
          'definition': kb.definition,
        }),
      );
    });

    developer.registerExtension('ext.vial.screenshot', (method, params) async {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'no boundary',
        );
      }
      final ratio = double.tryParse(params['ratio'] ?? '') ?? 1.0;
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'type': 'Screenshot',
          'width': image.width,
          'height': image.height,
          'png': base64Encode(bytes!.buffer.asUint8List()),
        }),
      );
    });

    developer.registerExtension('ext.vial.tap', (method, params) async {
      final x = double.parse(params['x']!);
      final y = double.parse(params['y']!);
      final pos = Offset(x, y);
      final binding = GestureBinding.instance;
      binding.handlePointerEvent(PointerDownEvent(position: pos));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      binding.handlePointerEvent(PointerUpEvent(position: pos));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'type': 'Tap', 'x': x, 'y': y}),
      );
    });

    developer.registerExtension('ext.vial.text', (method, params) async {
      final text = params['text'] ?? '';
      final out = <String>[];
      void visit(Element e) {
        final w = e.widget;
        if (w is Text && w.data != null) out.add(w.data!);
        if (w is RichText) out.add(w.text.toPlainText());
        e.visitChildren(visit);
      }

      final root = WidgetsBinding.instance.rootElement;
      if (root != null) visit(root);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'type': 'Texts',
          'filter': text,
          'texts': text.isEmpty
              ? out
              : out.where((t) => t.contains(text)).toList(),
        }),
      );
    });
  }
}
