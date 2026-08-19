import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'services/analytics_service.dart';
import 'models/analytics_models.dart';
import 'utils/csv_export_util.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics summary exported as CSV successfully!'),
            backgroundColor: Color(0xff15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
          'Analytics & Insights',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
                : const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export CSV',
            onPressed: _loadedSummary == null ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: FutureBuilder<AnalyticsSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: accentColor, strokeWidth: 3),
                    const SizedBox(height: 14),
                    Text(
                      'Aggregating 30-day inventory metrics...',
                      style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load analytics.',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                        ),
                      ),
                    ],
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
              color: accentColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overview Hero Card
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
                              Icons.analytics_rounded,
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
                                  'Activity & Stock Metrics',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rolling 30-day loans, returns & inventory distribution',
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

                    // Stat Grid (4 KPI Cards)
                    _StatGrid(data: data),
                    const SizedBox(height: 24),

                    // Section: Top Requested Components
                    _SectionHeader(title: 'Top Requested Components', icon: Icons.trending_up_rounded),
                    const SizedBox(height: 10),
                    _TopComponentsCard(components: data.topComponents),
                    const SizedBox(height: 24),

                    // Section: Stock by Category
                    _SectionHeader(title: 'Stock & Loan Distribution by Category', icon: Icons.pie_chart_outline_rounded),
                    const SizedBox(height: 10),
                    _CategoryStockCard(categories: data.categoryStock),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AnalyticsSummary data;
  const _StatGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);

    final stats = [
      _StatCardData(
        'Total Issued',
        data.totalIssuedLast30Days.toString(),
        Icons.arrow_upward_rounded,
        isDark ? const Color(0xff38BDF8) : const Color(0xff0284C7),
      ),
      _StatCardData(
        'Total Returned',
        data.totalReturnedLast30Days.toString(),
        Icons.arrow_downward_rounded,
        isDark ? const Color(0xff4ADE80) : const Color(0xff16A34A),
      ),
      _StatCardData(
        'Currently Out',
        data.activeIssuesNow.toString(),
        Icons.schedule_rounded,
        isDark ? const Color(0xffFB923C) : const Color(0xffEA580C),
      ),
      _StatCardData(
        'Members Served',
        data.uniqueMembersServedLast30Days.toString(),
        Icons.people_alt_rounded,
        isDark ? const Color(0xffC084FC) : const Color(0xff9333EA),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
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
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CAppTheme.cardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
              Text(
                '30 Days',
                style: GoogleFonts.lato(fontSize: 10.5, color: secondaryText),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          Text(
            data.label,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: secondaryText,
              fontWeight: FontWeight.w600,
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
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff0284C7);

    if (components.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: CAppTheme.cardDecoration(context, radius: 16),
        child: Text(
          'No components issued in the last 30 days.',
          style: GoogleFonts.lato(color: secondaryText),
        ),
      );
    }

    final maxVal = components.map((c) => c.totalIssued).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CAppTheme.cardDecoration(context, radius: 16),
      child: Column(
        children: components.map((c) {
          final fraction = maxVal == 0 ? 0.0 : c.totalIssued / maxVal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
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
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${c.totalIssued} issued',
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
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
                          Container(
                            height: 7,
                            width: constraints.maxWidth,
                            color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 7,
                            width: constraints.maxWidth * fraction,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? const [Color(0xff38BDF8), Color(0xff0284C7)]
                                    : const [Color(0xff19335A), Color(0xff0845BB)],
                              ),
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
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CAppTheme.cardDecoration(context, radius: 16),
      child: Column(
        children: categories.map((cat) {
          final total = cat.totalStock == 0 ? 1 : cat.totalStock;
          final issuedFraction = (cat.currentlyIssued / total).clamp(0.0, 1.0);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat.category,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    Text(
                      '${cat.currentlyIssued} out / ${cat.totalStock} total',
                      style: GoogleFonts.lato(fontSize: 11.5, color: secondaryText),
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
                          Container(
                            height: 7,
                            width: constraints.maxWidth,
                            color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                          ),
                          Container(
                            height: 7,
                            width: constraints.maxWidth * issuedFraction,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xffFB923C) : const Color(0xffEA580C),
                              borderRadius: BorderRadius.circular(8),
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
