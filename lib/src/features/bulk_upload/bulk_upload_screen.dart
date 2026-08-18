import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'models/bulk_upload_models.dart';
import 'services/bulk_upload_service.dart';

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final BulkUploadService _service = BulkUploadService();
  String? _pickedFileName;
  String? _csvContent;
  int _rowCount = 0;
  bool _isUploading = false;
  BulkUploadReport? _report;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final content = utf8.decode(result.files.single.bytes!);
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();

    setState(() {
      _pickedFileName = result.files.single.name;
      _csvContent = content;
      _rowCount = lines.length > 1 ? lines.length - 1 : 0; // Exclude header
      _report = null;
    });
  }

  Future<void> _upload() async {
    if (_csvContent == null) return;
    setState(() => _isUploading = true);
    try {
      final report = await _service.uploadFromCsv(_csvContent!);
      setState(() => _report = report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processed ${_rowCount} items: ${report.added} added, ${report.updated} updated.'),
            backgroundColor: const Color(0xff15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff080E1A) : const Color(0xffF0F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bulk Upload Inventory',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner Hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xff0F172A), Color(0xff1E293B)]
                        : const [Color(0xff19335A), Color(0xff2A4E80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xff38BDF8).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xff38BDF8).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        color: isDark ? const Color(0xff38BDF8) : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV Batch Import',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bulk add or update hardware stock across all 7 categories',
                            style: GoogleFonts.lato(
                              color: isDark ? const Color(0xff94A3B8) : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // File Selection Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: CAppTheme.cardDecoration(context, radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_file_rounded, size: 18, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Upload CSV File',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // File Picker Dropzone
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xff38BDF8).withValues(alpha: 0.4) : const Color(0xff0284C7).withValues(alpha: 0.4),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _pickedFileName != null ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                              size: 38,
                              color: _pickedFileName != null
                                  ? (isDark ? const Color(0xff4ADE80) : Colors.green)
                                  : accentColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _pickedFileName ?? 'Tap to select a .CSV file',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            if (_pickedFileName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$_rowCount components detected',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xff4ADE80) : Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'Supports comma-separated values (.csv)',
                                style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Process / Upload Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_csvContent == null || _isUploading) ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isUploading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: isDark ? const Color(0xff080E1A) : Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.sync_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Process & Import Inventory',
                                    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Upload Execution Report
              if (_report != null) ...[
                const SizedBox(height: 20),
                _ReportCard(report: _report!),
              ],

              const SizedBox(height: 20),

              // Format Guidelines Card
              const _InstructionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard();

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: CAppTheme.cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'CSV Formatting Guide',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Required Columns: category, skuid, name, stock\n'
            '• Optional Columns: boxno, warning\n\n'
            'Allowed Categories:\n'
            'Microcontroller, Sensors, Communication Modules, Displays and Indicators, '
            'Actuators and Motors, Power Components, Others\n\n'
            'Behavior:\n'
            'If a skuid already exists in that category, its stock/boxno will be updated. '
            'If it is a new SKU, a new hardware record is created.',
            style: GoogleFonts.lato(fontSize: 12.5, color: secondaryText, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final BulkUploadReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import Results',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CountPill(
                label: 'Added',
                count: report.added,
                color: isDark ? const Color(0xff4ADE80) : const Color(0xff16A34A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountPill(
                label: 'Updated',
                count: report.updated,
                color: isDark ? const Color(0xff38BDF8) : const Color(0xff0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountPill(
                label: 'Failed',
                count: report.failed.length,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        if (report.failed.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Failed Rows (${report.failed.length})',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: CAppTheme.cardDecoration(context, radius: 14),
            child: Column(
              children: report.failed.map((f) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  title: Text(
                    'Row ${f.rowNumber}${f.skuid.isNotEmpty ? " (${f.skuid})" : ""}',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  subtitle: Text(
                    f.message,
                    style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountPill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: CAppTheme.cardDecoration(context, radius: 14),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
