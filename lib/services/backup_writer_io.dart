import 'dart:io';
import 'dart:typed_data';

/// Native (Android / iOS / desktop): write the bytes to the chosen path.
Future<void> writeBytesToPath(String path, Uint8List bytes) =>
    File(path).writeAsBytes(bytes, flush: true);
