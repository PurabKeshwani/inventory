import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Runs on Android/iOS/desktop builds — no browser download bar exists there,
// so "download" means handing the file to the OS share/save sheet.
Future<void> downloadCsv(String csvContent, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csvContent);
  await Share.shareXFiles([XFile(file.path)], subject: fileName);
}
