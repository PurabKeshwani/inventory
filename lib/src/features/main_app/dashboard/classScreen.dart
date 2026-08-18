import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/components_in_class_screen/component_in_class_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/realtime_inventory_service.dart';

class Classscreen extends StatefulWidget {
  const Classscreen({required this.title, super.key});

  final String title;

  @override
  State<Classscreen> createState() => _ClassscreenState();
}

class _ClassscreenState extends State<Classscreen> {
  final ComponentController controller = Get.find<ComponentController>();
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  List<Component> _components = [];
  String _searchQuery = '';
  late RealtimeInventoryService realtimeService;
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    controller.Classcomponents.clear();
    realtimeService = RealtimeInventoryService();

    _loadComponents();

    channel = realtimeService.subscribe(
      getTableNameByTitle(widget.title),
      () async {
        await _loadComponents(forceRefresh: true);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      channel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  String getTableNameByTitle(String title) {
    final t = title.trim().toLowerCase();
    switch (t) {
      case 'microcontroller':
        return 'Microcontroller';
      case 'communication modules':
        return 'Communication Modules';
      case 'sensors':
        return 'Sensors';
      case 'displays and indicators':
        return 'Displays and Indicators';
      case 'actuators and motors':
        return 'Actuators and Motors';
      case 'power components':
        return 'Power Components';
      case 'others':
        return 'Others';
      default:
        return title;
    }
  }

  Future<void> _loadComponents({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
    });

    final tableName = getTableNameByTitle(widget.title);

    try {
      List<dynamic> rows = [];

      // 1. Check cache first unless forceRefresh is true
      if (!forceRefresh) {
        try {
          final cache = Get.find<CacheController>();
          final cached = cache.get<dynamic>(tableName);
          if (cached != null && cached.isNotEmpty) {
            rows = cached;
          }
        } catch (_) {}
      }

      // 2. Fetch from Supabase
      if (rows.isEmpty) {
        final res = await supabase.from(tableName).select();
        rows = res;
        try {
          Get.find<CacheController>().set(tableName, res);
        } catch (_) {}
      }

      // 3. Aggregate by unique component name
      final Map<String, Component> componentMap = {};
      final Map<String, int> totalCountMap = {};
      final Map<String, int> availableCountMap = {};

      for (var r in rows) {
        String name = '';
        String skuid = '';
        String boxNo = '';
        int stockVal = 0;
        int? warningVal;

        if (r is Component) {
          name = r.name.trim();
          skuid = r.skuId ?? '';
          boxNo = r.boxNo;
          stockVal = r.stock;
          warningVal = r.warning;
        } else if (r is Map) {
          name = (r['name'] ?? r['compname'] ?? '').toString().trim();
          skuid = (r['skuid'] ?? '').toString();
          boxNo = (r['boxNo'] ?? r['boxno'] ?? r['box_no'] ?? 'N/A').toString();
          stockVal = int.tryParse(r['stock']?.toString() ?? '0') ?? 0;
          warningVal = int.tryParse(r['warning']?.toString() ?? '');
        } else {
          continue;
        }

        if (name.isEmpty) continue;
        final key = name.toLowerCase();

        componentMap.putIfAbsent(
          key,
          () => Component(
            skuId: skuid,
            name: name,
            boxNo: boxNo,
            stock: 0,
            warning: warningVal,
          ),
        );

        totalCountMap[key] = (totalCountMap[key] ?? 0) + 1;

        if (stockVal > 0) {
          availableCountMap[key] = (availableCountMap[key] ?? 0) + 1;
        }
      }

      final uniqueComponents = componentMap.entries.map((entry) {
        final key = entry.key;
        final comp = entry.value;

        return Component(
          skuId: comp.skuId,
          name: comp.name,
          boxNo: comp.boxNo,
          stock: totalCountMap[key] ?? 0,
          availableStock: availableCountMap[key] ?? 0,
          issuedStock: (totalCountMap[key] ?? 0) - (availableCountMap[key] ?? 0),
          warning: comp.warning,
        );
      }).toList();

      // Sort alphabetically by name
      uniqueComponents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _components = uniqueComponents;
          controller.setComponents(uniqueComponents);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _components = [];
          isLoading = false;
        });
      }
    }
  }

  List<Component> get _filteredComponents {
    if (_searchQuery.isEmpty) return _components;
    final q = _searchQuery.toLowerCase();
    return _components
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.boxNo.toLowerCase().contains(q) ||
            (c.skuId != null && c.skuId!.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tableName = getTableNameByTitle(widget.title);
    final displayedList = _filteredComponents;

    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => _loadComponents(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            color: const Color(0xff19335A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                style: GoogleFonts.lato(fontSize: 13, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title}...',
                  hintStyle: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xff19335A)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),

          // Component List Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xff19335A)),
                    ),
                  )
                : displayedList.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _loadComponents(forceRefresh: true),
                        color: const Color(0xff19335A),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff19335A).withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 48,
                                      color: Color(0xff19335A),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No components matching "$_searchQuery"'
                                        : 'No Components in ${widget.title}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Swipe down to refresh or check back later.',
                                    style: GoogleFonts.lato(fontSize: 12.5, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadComponents(forceRefresh: true),
                        color: const Color(0xff19335A),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: displayedList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final component = displayedList[index];
                            final available = component.availableStock;
                            final total = component.stock;
                            final issued = component.issuedStock;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xffE2EAF4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.025),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ComponentInClassScreen(
                                          component: component,
                                          category: tableName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Row(
                                      children: [
                                        // Component Icon Avatar
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xff19335A).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.memory_rounded,
                                            size: 22,
                                            color: Color(0xff19335A),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Component Name & Box Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                component.name,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xff19335A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Box: ${component.boxNo}',
                                                style: GoogleFonts.lato(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Stock Breakdown Badges
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Available Stock Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: available > 0
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.red.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '$available Available',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: available > 0 ? Colors.green[800] : Colors.red[800],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Total: $total • Issued: $issued',
                                              style: GoogleFonts.lato(
                                                fontSize: 10.5,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.grey[400],
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
