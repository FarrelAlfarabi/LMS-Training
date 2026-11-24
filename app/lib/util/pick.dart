import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class Picked {
  final String name;
  final Uint8List bytes;
  Picked(this.name, this.bytes);
}

/// Lets the person choose one file and reads it. Null when they cancel.
Future<Picked?> pickOne({FileType type = FileType.custom, List<String>? extensions}) async {
  final files = await FilePicker.pickFiles(type: type, allowedExtensions: type == FileType.custom ? extensions : null);
  if (files.isEmpty) return null;
  final f = files.first;
  return Picked(f.name, await f.readAsBytes());
}
