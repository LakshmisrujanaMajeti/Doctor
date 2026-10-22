import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as platform;

/// Downloads raw file bytes to the user's device (browser download on Web, storage on Mobile).
Future<void> downloadFileBytes(List<int> bytes, String fileName) async {
  await platform.downloadFileBytes(bytes, fileName);
}
