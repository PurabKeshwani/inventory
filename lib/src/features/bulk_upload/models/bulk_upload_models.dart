class BulkUploadRowResult {
  final int rowNumber;
  final String skuid;
  final String message;

  BulkUploadRowResult({
    required this.rowNumber,
    required this.skuid,
    required this.message,
  });
}

class BulkUploadReport {
  final int added;
  final int skipped;
  final List<BulkUploadRowResult> failed;

  BulkUploadReport({
    required this.added,
    required this.skipped,
    required this.failed,
  });

  int get totalProcessed => added + skipped;
}
