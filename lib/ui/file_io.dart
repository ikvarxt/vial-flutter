import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Result of an open-file dialog.
class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Opens a file chooser filtered on [extension] and returns its bytes.
Future<PickedFile?> pickFile({
  required String extension,
  String? dialogTitle,
}) async {
  final files = await FilePicker.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
  if (files.isEmpty) return null;
  final f = files.first;
  final bytes = await f.readAsBytes();
  return PickedFile(f.name, bytes);
}

/// Shows a save dialog (or triggers a download on the web) for [bytes].
Future<bool> saveFile({
  required String fileName,
  required Uint8List bytes,
  required String extension,
  String? dialogTitle,
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
  return uri != null;
}
