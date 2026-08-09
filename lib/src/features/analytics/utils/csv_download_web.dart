import 'dart:convert';
import 'dart:html' as html;

// Runs when the app is served as Flutter Web (your current test target).
// Triggers a native browser download via a Blob + temporary anchor click —
// no server round-trip, no share-sheet dependency.
Future<void> downloadCsv(String csvContent, String fileName) async {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
