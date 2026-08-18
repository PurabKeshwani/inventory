import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/bulk_upload_models.dart';
import 'services/bulk_upload_service.dart';

const _navy = Color(0xff19335A);
const _accent = Color(0xff0845BB);
const _bg = Color(0xffF7F8FC);

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final BulkUploadService _service = BulkUploadService();
  String? _pickedFileName;
  String? _csvContent;
  bool _isUploading = false;
  BulkUploadReport? _report;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // required for web; harmless on mobile/desktop
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _pickedFileName = result.files.single.name;
      _csvContent = utf8.decode(result.files.single.bytes!);
      _report = null;
    });
  }

  Future<void> _upload() async {
    if (_csvContent == null) return;
    setState(() => _isUploading = true);
    try {
      final report = await _service.uploadFromCsv(_csvContent!);
      setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        title: Text(
          'Bulk Upload Inventory',
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InstructionsCard(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CSV File', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Choose CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedFileName ?? 'No file selected',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_csvContent == null || _isUploading) ? null : _upload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Upload'),
                    ),
                  ),
                ],
              ),
            ),
            if (_report != null) ...[
              const SizedBox(height: 24),
              _ReportCard(report: _report!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CSV Format', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 8),
          Text(
            'Required columns: category, skuid, name, stock\n'
            'Optional columns: boxno, warning\n\n'
            'category must be one of: Microcontroller, Sensors, Communication Modules, '
            'Displays and Indicators, Actuators and Motors, Power Components, Others\n\n'
            'If a skuid already exists in that category, its name/boxno/stock will be updated. '
            'If it\'s new, a new item is created.',
            style: GoogleFonts.montserrat(fontSize: 12.5, color: Colors.black54, height: 1.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _CountPill(label: 'Added', count: report.added, color: Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _CountPill(label: 'Updated', count: report.updated, color: _accent)),
            const SizedBox(width: 10),
            Expanded(child: _CountPill(label: 'Failed', count: report.failed.length, color: Colors.red)),
          ],
        ),
        if (report.failed.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Rows that failed', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: report.failed.map((f) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  title: Text(
                    'Row ${f.rowNumber}${f.skuid.isNotEmpty ? " (${f.skuid})" : ""}',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(f.message, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54)),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text('$count', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}
