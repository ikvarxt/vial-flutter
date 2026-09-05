// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Debug-only VM service extensions used to drive and screenshot the app
/// from the command line on platforms where no native automation is available
/// (`ext.vial.screenshot`, `ext.vial.tap`, `ext.vial.text`).
class UiProbe {
  UiProbe._();

  static final GlobalKey boundaryKey = GlobalKey();
  static bool _registered = false;

  static Widget wrap(Widget child) =>
      RepaintBoundary(key: boundaryKey, child: child);

  static void register() {
    if (!kDebugMode || _registered) return;
    _registered = true;

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
