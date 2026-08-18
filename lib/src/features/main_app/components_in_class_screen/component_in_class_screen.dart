import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/outputComponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/authentication/controllers/selectquerycontroller.dart';
import 'package:inventory/src/utils/barcode_util.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComponentInClassScreen extends StatefulWidget {
  final Component component;
  final String? category;

  const ComponentInClassScreen({
    super.key,
    required this.component,
    this.category,
  });

  @override
  _ComponentInClassScreenState createState() => _ComponentInClassScreenState();
}

class _ComponentInClassScreenState extends State<ComponentInClassScreen> {
  final supabase = Supabase.instance.client;
  final ComponentController componentControl = Get.find<ComponentController>();
  final Selectquerycontroller selectquerycontroller =
      Get.put(Selectquerycontroller());
  final TextEditingController warningController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'available', 'issued'

  @override
  void initState() {
    super.initState();
    selectquerycontroller.fetchComponents(
      widget.component.name,
      targetTable: widget.category,
    );
  }

  @override
  void dispose() {
    warningController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await selectquerycontroller.fetchComponents(
      widget.component.name,
      targetTable: widget.category,
    );
  }

  List<Outputcomponent> get _filteredList {
    final query = searchController.text.trim().toLowerCase();
    return selectquerycontroller.newres.where((item) {
      final isAvailable = item.stock > 0;
      if (_filterStatus == 'available' && !isAvailable) return false;
      if (_filterStatus == 'issued' && isAvailable) return false;

      if (query.isNotEmpty) {
        final skuid = item.skuid.toLowerCase();
        final box = item.boxNo.toLowerCase();
        return skuid.contains(query) || box.contains(query);
      }
      return true;
    }).toList();
  }

  void _showBarcodeDialog(Outputcomponent item) {
    final sku = item.skuid;
    final box = item.boxNo;
    final isAvailable = item.stock > 0;
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Component Barcode',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.component.name,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff0F172A) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xff334155) : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'Box: $box',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xffCBD5E1) : Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAvailable ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isAvailable ? 'AVAILABLE (STOCK: ${item.stock})' : 'ISSUED',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Barcode Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    BarcodeWidget(
                      data: sku,
                      height: 80,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sku,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: sku));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('SKU ID copied to clipboard')),
                            );
                          },
                          child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Download / Share Barcode Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download / Share Barcode',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff19335A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    BarcodeUtil.downloadOrShareBarcode(
                      context: context,
                      skuId: sku,
                      compName: widget.component.name,
                      boxNo: box,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _tableName {
    if (widget.category != null && widget.category!.isNotEmpty) {
      return widget.category!;
    }
    return componentControl.ClassName.value;
  }

  void _showComponentActionsBottomSheet(Outputcomponent item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff19335A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xff19335A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.skuid,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff19335A),
                          ),
                        ),
                        Text(
                          '${widget.component.name} • Box: ${item.boxNo}',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Option 1: View Barcode
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded,
                    color: Color(0xff19335A)),
                title: Text('View Barcode',
                    style: GoogleFonts.montserrat(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Show, copy or download barcode image',
                    style: GoogleFonts.lato(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBarcodeDialog(item);
                },
              ),

              // Option 2: Edit Component
              ListTile(
                leading: const Icon(Icons.edit_note_rounded,
                    color: Color(0xff0845BB)),
                title: Text('Edit Component',
                    style: GoogleFonts.montserrat(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Change box number, stock quantity, or notes',
                    style: GoogleFonts.lato(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditFullComponentDialog(item);
                },
              ),

              // Option 3: Delete Component
              ListTile(
                leading:
                    const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: Text('Delete Component',
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red)),
                subtitle: Text('Permanently remove this SKU instance from inventory',
                    style: GoogleFonts.lato(fontSize: 12, color: Colors.red[300])),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteComponent(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditFullComponentDialog(Outputcomponent item) async {
    final isDark = CAppTheme.isDark(context);
    final boxController = TextEditingController(text: item.boxNo);
    final stockController = TextEditingController(text: item.stock.toString());
    final noteController = TextEditingController(text: item.warning?.toString() ?? '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
          ),
        ),
        title: Text(
          'Edit Component (${item.skuid})',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xff19335A),
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: boxController,
                style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Box Number',
                  labelStyle: TextStyle(color: isDark ? const Color(0xff94A3B8) : Colors.grey[700]),
                  filled: true,
                  fillColor: isDark ? const Color(0xff0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  labelStyle: TextStyle(color: isDark ? const Color(0xff94A3B8) : Colors.grey[700]),
                  filled: true,
                  fillColor: isDark ? const Color(0xff0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Warning / Notes',
                  labelStyle: TextStyle(color: isDark ? const Color(0xff94A3B8) : Colors.grey[700]),
                  filled: true,
                  fillColor: isDark ? const Color(0xff0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(
                color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Save Changes', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newBox = boxController.text.trim();
      final newStock = int.tryParse(stockController.text.trim()) ?? item.stock;
      final newNote = noteController.text.trim();

      final tableName = _tableName;
      try {
        await supabase.from(tableName).update({
          'boxNo': newBox,
          'stock': newStock,
          'warning': newNote,
        }).eq('skuid', item.skuid);

        // Invalidate cache
        try {
          Get.find<CacheController>().invalidate(tableName);
        } catch (_) {}

        await _refreshData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Component updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update component: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteComponent(Outputcomponent item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Component?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.red[800],
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete SKU "${item.skuid}" (${widget.component.name}) from inventory? This action cannot be undone.',
          style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[800], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Delete', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final tableName = _tableName;
      try {
        await supabase.from(tableName).delete().eq('skuid', item.skuid);

        // Invalidate cache
        try {
          Get.find<CacheController>().invalidate(tableName);
        } catch (_) {}

        await _refreshData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Component deleted successfully!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete component: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        elevation: 0,
        title: Text(
          widget.component.name,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: accentColor,
          child: Obx(() {
            final allItems = selectquerycontroller.newres;
            final totalCount = allItems.length;
            final availableCount =
                allItems.where((i) => (i.stock ?? 0) > 0).length;
            final issuedCount = totalCount - availableCount;
            final displayedItems = _filteredList;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Summary Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Total Units',
                                count: totalCount.toString(),
                                color: accentColor,
                                icon: Icons.inventory_2_rounded,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Available',
                                count: availableCount.toString(),
                                color: isDark ? const Color(0xff4ADE80) : Colors.green[700]!,
                                icon: Icons.check_circle_rounded,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Issued',
                                count: issuedCount.toString(),
                                color: isDark ? const Color(0xffF87171) : Colors.red[700]!,
                                icon: Icons.output_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Search & Filter Bar
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: CAppTheme.cardDecoration(context, radius: 10),
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search SKU or Box...',
                                    hintStyle: GoogleFonts.lato(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xff64748B) : Colors.grey,
                                    ),
                                    prefixIcon: Icon(Icons.search, size: 20, color: accentColor),
                                    suffixIcon: searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear, size: 18, color: secondaryText),
                                            onPressed: () {
                                              searchController.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'All ($totalCount)', isDark: isDark),
                              const SizedBox(width: 8),
                              _buildFilterChip('available', 'Available ($availableCount)',
                                  color: isDark ? const Color(0xff4ADE80) : Colors.green,
                                  isDark: isDark),
                              const SizedBox(width: 8),
                              _buildFilterChip('issued', 'Issued ($issuedCount)',
                                  color: isDark ? const Color(0xffF87171) : Colors.red,
                                  isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Table Header Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Components & Inventory Units',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            Text(
                              'Tap row to view barcode',
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Table Content
                if (selectquerycontroller.isLoading.value)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: accentColor,
                      ),
                    ),
                  )
                else if (displayedItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_rounded,
                              size: 54, color: isDark ? const Color(0xff475569) : Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No components found',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xffCBD5E1) : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: CAppTheme.cardDecoration(context, radius: 12),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
                            ),
                            headingTextStyle: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('SKU ID')),
                              DataColumn(label: Text('Box No')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Stock')),
                              DataColumn(label: Text('Warning / Note')),
                              DataColumn(label: Text('Barcode')),
                            ],
                            rows: displayedItems.map((item) {
                              final isAvailable = item.stock > 0;
                              return DataRow(
                                onSelectChanged: (_) => _showBarcodeDialog(item),
                                cells: [
                                  DataCell(
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showBarcodeDialog(item),
                                      onLongPress: () => _showComponentActionsBottomSheet(item),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 180),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.qr_code_2_rounded,
                                                size: 18, color: accentColor),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                item.skuid,
                                                style: GoogleFonts.sourceCodePro(
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryText,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showBarcodeDialog(item),
                                      onLongPress: () => _showComponentActionsBottomSheet(item),
                                      child: Text(
                                        item.boxNo,
                                        style: GoogleFonts.lato(
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xffCBD5E1) : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showBarcodeDialog(item),
                                      onLongPress: () => _showComponentActionsBottomSheet(item),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green[50])
                                              : (isDark ? Colors.red.withOpacity(0.2) : Colors.red[50]),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isAvailable
                                                ? (isDark ? Colors.green.withOpacity(0.4) : Colors.green)
                                                : (isDark ? Colors.red.withOpacity(0.4) : Colors.red),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isAvailable
                                                  ? Icons.check_circle_rounded
                                                  : Icons.cancel_rounded,
                                              size: 14,
                                              color: isAvailable
                                                  ? (isDark ? const Color(0xff4ADE80) : Colors.green[700])
                                                  : (isDark ? const Color(0xffF87171) : Colors.red[700]),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAvailable ? 'Available' : 'Issued',
                                              style: GoogleFonts.lato(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable
                                                    ? (isDark ? const Color(0xff4ADE80) : Colors.green[800])
                                                    : (isDark ? const Color(0xffF87171) : Colors.red[800]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showBarcodeDialog(item),
                                      onLongPress: () => _showComponentActionsBottomSheet(item),
                                      child: Text(
                                        item.stock.toString(),
                                        style: GoogleFonts.lato(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? const Color(0xffF1F5F9) : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: InkWell(
                                        onTap: () => _showEditFullComponentDialog(item),
                                        onLongPress: () => _showComponentActionsBottomSheet(item),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (item.warning != null &&
                                                item.warning.toString().isNotEmpty) ...[
                                              const Icon(Icons.warning_amber_rounded,
                                                  size: 16, color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  item.warning.toString(),
                                                  style: GoogleFonts.lato(
                                                      color: Colors.orange[400],
                                                      fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ] else ...[
                                              Text(
                                                'Add note',
                                                style: GoogleFonts.lato(
                                                    fontSize: 12,
                                                    color: secondaryText,
                                                    fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit,
                                                size: 12, color: secondaryText),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.qr_code_rounded,
                                              color: accentColor),
                                          tooltip: 'View Barcode (Tap)',
                                          onPressed: () => _showBarcodeDialog(item),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.more_vert_rounded,
                                              color: secondaryText),
                                          tooltip: 'Edit / Delete (Long Press)',
                                          onPressed: () => _showComponentActionsBottomSheet(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xff334155) : color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: isDark ? const Color(0xff94A3B8) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? color, bool isDark = false}) {
    final isSelected = _filterStatus == filterKey;
    final activeColor = color ?? (isDark ? const Color(0xff0284C7) : const Color(0xff19335A));

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? const Color(0xff94A3B8) : (color ?? const Color(0xff19335A))),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
      side: BorderSide(
        color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
      ),
      onSelected: (_) {
        setState(() {
          _filterStatus = filterKey;
        });
      },
    );
  }
}
