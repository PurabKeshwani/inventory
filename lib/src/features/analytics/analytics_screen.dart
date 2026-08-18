import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/analytics_service.dart';
import 'models/analytics_models.dart';
import 'utils/csv_export_util.dart';

const _navy = Color(0xff19335A);
const _accent = Color(0xff0845BB);
const _bg = Color(0xffF7F8FC);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _service = AnalyticsService();
  late Future<AnalyticsSummary> _future;
  AnalyticsSummary? _loadedSummary;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _future = _service.loadLast30DaysSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.loadLast30DaysSummary();
    });
    await _future;
  }

  Future<void> _exportCsv() async {
    if (_loadedSummary == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await CsvExportUtil.exportSummary(_loadedSummary!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
          'Analytics',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Export as CSV',
            onPressed: _loadedSummary == null ? null : _exportCsv,
          ),
        ],
      ),
      body: FutureBuilder<AnalyticsSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load analytics.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: Colors.black54),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          if (_loadedSummary != data) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loadedSummary = data);
            });
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: _navy,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 30 days',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatGrid(data: data),
                  const SizedBox(height: 28),
                  _SectionHeader('Top Requested Components'),
                  const SizedBox(height: 12),
                  _TopComponentsCard(components: data.topComponents),
                  const SizedBox(height: 28),
                  _SectionHeader('Stock by Category'),
                  const SizedBox(height: 12),
                  _CategoryStockCard(categories: data.categoryStock),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _navy,
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AnalyticsSummary data;
  const _StatGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatCardData('Issued', data.totalIssuedLast30Days.toString(), Icons.north_east_rounded, _accent),
      _StatCardData('Returned', data.totalReturnedLast30Days.toString(), Icons.south_west_rounded, Colors.teal),
      _StatCardData('Currently Out', data.activeIssuesNow.toString(), Icons.pending_actions_rounded, Colors.orange),
      _StatCardData('Members Served', data.uniqueMembersServedLast30Days.toString(), Icons.groups_rounded, _navy),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, i) => _StatCard(data: stats[i]),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatCardData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.color),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          Text(
            data.label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopComponentsCard extends StatelessWidget {
  final List<ComponentPopularity> components;
  const _TopComponentsCard({required this.components});

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) {
      return _EmptyState(message: 'No components issued in the last 30 days.');
    }

    final maxVal = components.map((c) => c.totalIssued).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: components.map((c) {
          final fraction = maxVal == 0 ? 0.0 : c.totalIssued / maxVal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${c.totalIssued}',
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _accent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(height: 8, width: constraints.maxWidth, color: Colors.grey[200]),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 8,
                            width: constraints.maxWidth * fraction,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [_accent, _navy]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryStockCard extends StatelessWidget {
  final List<CategoryStock> categories;
  const _CategoryStockCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: categories.map((cat) {
          final total = cat.totalStock == 0 ? 1 : cat.totalStock;
          final issuedFraction = (cat.currentlyIssued / total).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat.category,
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${cat.currentlyIssued} out / ${cat.totalStock} total',
                      style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(height: 8, width: constraints.maxWidth, color: Colors.teal.withOpacity(0.15)),
                          Container(
                            height: 8,
                            width: constraints.maxWidth * issuedFraction,
                            color: Colors.orange,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(color: Colors.black45),
      ),
    );
  }
}
