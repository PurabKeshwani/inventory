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
  final int updated;
  final List<BulkUploadRowResult> failed;

  BulkUploadReport({
    required this.added,
    required this.updated,
    required this.failed,
  });

  int get totalProcessed => added + updated;
}
