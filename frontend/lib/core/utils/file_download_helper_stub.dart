import 'dart:io';

Future<void> downloadFileBytes(List<int> bytes, String fileName) async {
  try {
    // For Android, check common public download directories
    final candidates = [
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Download'),
      Directory.systemTemp,
    ];
    for (final dir in candidates) {
      if (dir.existsSync()) {
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return;
      }
    }
  } catch (_) {}
}
