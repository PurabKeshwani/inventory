import 'package:csv/csv.dart';
import '../models/analytics_models.dart';
import 'csv_download.dart';

class CsvExportUtil {
  // Takes the SAME AnalyticsSummary object already rendered on screen —
  // this is what makes the export match whatever's currently being viewed,
  // rather than re-querying with different logic.
  static Future<void> exportSummary(AnalyticsSummary summary) async {
    final rows = <List<dynamic>>[];

    rows.add(['Inventorium Analytics Export']);
    rows.add(['Generated on', DateTime.now().toString()]);
    rows.add(['Window', 'Last 30 days']);
    rows.add([]);

    rows.add(['-- Summary --']);
    rows.add(['Metric', 'Value']);
    rows.add(['Issued (30d)', summary.totalIssuedLast30Days]);
    rows.add(['Returned (30d)', summary.totalReturnedLast30Days]);
    rows.add(['Currently Out (all time)', summary.activeIssuesNow]);
    rows.add(['Members Served (30d)', summary.uniqueMembersServedLast30Days]);
    rows.add([]);

    rows.add(['-- Top Requested Components (30d) --']);
    rows.add(['Component', 'SKU ID', 'Times Issued']);
    for (final c in summary.topComponents) {
      rows.add([c.name, c.skuid, c.totalIssued]);
    }
    rows.add([]);

    rows.add(['-- Stock by Category (all time) --']);
    rows.add(['Category', 'Total Stock', 'Currently Issued', 'Available']);
    for (final c in summary.categoryStock) {
      rows.add([c.category, c.totalStock, c.currentlyIssued, c.available]);
    }

    // Note: no Fines section — there is no fines data model in the current
    // schema, so it's intentionally omitted rather than shown as fake zeros.

    final csvContent = const ListToCsvConverter().convert(rows);
    final fileName = 'inventorium_analytics_${DateTime.now().millisecondsSinceEpoch}.csv';
    await downloadCsv(csvContent, fileName);
  }
}
