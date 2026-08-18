import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/Actuators&Motors.dart';
import 'package:inventory/src/data/Communication%20Modules.dart';
import 'package:inventory/src/data/DisplaysandIndicators.dart';
import 'package:inventory/src/data/microControllerList.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/othermodulesandcomponents.dart';
import 'package:inventory/src/data/powercomponents.dart';
import 'package:inventory/src/data/sensors.dart';
import 'package:inventory/src/features/main_app/components_in_class_screen/component_in_class_screen.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class ComponentItemWithCategory {
  final Component component;
  final String category;

  ComponentItemWithCategory({
    required this.component,
    required this.category,
  });
}

class Componentcontroller extends GetxController {
  RxList<ComponentItemWithCategory> allItems = <ComponentItemWithCategory>[].obs;
  RxList<Component> foundComponents = <Component>[].obs;
  RxString selectedCategory = 'All'.obs;
  RxString searchQuery = ''.obs;

  void setAllComponents(List<ComponentItemWithCategory> items) {
    allItems.value = items;
    _updateFilteredList();
  }

  void filterByCategory(String category) {
    selectedCategory.value = category;
    _updateFilteredList();
  }

  void filterByQuery(String query) {
    searchQuery.value = query;
    _updateFilteredList();
  }

  void _updateFilteredList() {
    List<ComponentItemWithCategory> filtered = allItems;

    // Filter by Category
    if (selectedCategory.value != 'All') {
      filtered = filtered
          .where((item) =>
              item.category.toLowerCase() ==
              selectedCategory.value.toLowerCase())
          .toList();
    }

    // Filter by Search Query
    if (searchQuery.value.trim().isNotEmpty) {
      final q = searchQuery.value.trim().toLowerCase();
      filtered = filtered
          .where((item) =>
              item.component.name.toLowerCase().contains(q) ||
              item.component.boxNo.toLowerCase().contains(q) ||
              (item.component.skuId ?? '').toLowerCase().contains(q))
          .toList();
    }

    // Group matching components by name
    Map<String, int> groupedStock = {};
    Map<String, Component> groupedComponents = {};

    for (var item in filtered) {
      final comp = item.component;
      final key = comp.name.trim().toLowerCase();
      if (groupedStock.containsKey(key)) {
        groupedStock[key] = groupedStock[key]! + comp.stock;
      } else {
        groupedStock[key] = comp.stock;
        groupedComponents[key] = comp;
      }
    }

    // Convert to list
    List<Component> resultList = groupedComponents.entries.map((entry) {
      Component original = entry.value;
      return Component(
        skuId: original.skuId,
        name: original.name,
        boxNo: original.boxNo,
        stock: groupedStock[entry.key]!,
        warning: original.warning,
      );
    }).toList();

    // Sort alphabetically
    resultList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    foundComponents.value = resultList;
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final Componentcontroller controller = Get.put(Componentcontroller());
  final TextEditingController _textEditingController = TextEditingController();
  bool isLoading = true;

  final List<String> categories = [
    'All',
    'Microcontroller',
    'Sensors',
    'Communication Modules',
    'Displays and Indicators',
    'Actuators and Motors',
    'Power Components',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllComponents();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _loadAllComponents({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final List<ComponentItemWithCategory> items = [];

      final microcontrollers =
          await Microcontrollers().getComponents(forceRefresh: forceRefresh);
      for (var c in microcontrollers) {
        items.add(ComponentItemWithCategory(
            component: c, category: 'Microcontroller'));
      }

      final sensors =
          await Sensors().getComponents(forceRefresh: forceRefresh);
      for (var c in sensors) {
        items.add(ComponentItemWithCategory(component: c, category: 'Sensors'));
      }

      final comms = await CommunicationModules()
          .getComponents(forceRefresh: forceRefresh);
      for (var c in comms) {
        items.add(ComponentItemWithCategory(
            component: c, category: 'Communication Modules'));
      }

      final displays = await Displaysandindicators()
          .getComponents(forceRefresh: forceRefresh);
      for (var c in displays) {
        items.add(ComponentItemWithCategory(
            component: c, category: 'Displays and Indicators'));
      }

      final actuators = await ActuatorsandMotors()
          .getComponents(forceRefresh: forceRefresh);
      for (var c in actuators) {
        items.add(ComponentItemWithCategory(
            component: c, category: 'Actuators and Motors'));
      }

      final power =
          await Powercomponents().getComponents(forceRefresh: forceRefresh);
      for (var c in power) {
        items.add(ComponentItemWithCategory(
            component: c, category: 'Power Components'));
      }

      final others = await Othermodulesandcomponents()
          .getComponents(forceRefresh: forceRefresh);
      for (var c in others) {
        items.add(ComponentItemWithCategory(component: c, category: 'Others'));
      }

      controller.setAllComponents(items);
    } catch (e) {
      print('Error fetching all components: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  int get _totalUniqueComponents => controller.foundComponents.length;
  int get _totalUnits =>
      controller.foundComponents.fold(0, (sum, c) => sum + c.stock);

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadAllComponents(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Components',
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          Obx(() => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xff38BDF8).withValues(alpha: 0.2)
                                      : const Color(0xff19335A),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xff38BDF8).withValues(alpha: 0.4) : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$_totalUniqueComponents Types ($_totalUnits in stock)',
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xff38BDF8) : Colors.white,
                                  ),
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search bar
                      Container(
                        decoration: CAppTheme.cardDecoration(context, radius: 12),
                        child: TextField(
                          controller: _textEditingController,
                          onChanged: (value) => controller.filterByQuery(value),
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search components, box no, SKU...',
                            hintStyle: GoogleFonts.lato(
                              fontSize: 14,
                              color: isDark ? const Color(0xff64748B) : Colors.grey[500],
                            ),
                            prefixIcon: Icon(Icons.search, color: accentColor),
                            suffixIcon: _textEditingController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: secondaryText),
                                    onPressed: () {
                                      _textEditingController.clear();
                                      controller.filterByQuery('');
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(
                          () => Row(
                            children: categories.map((cat) {
                              final isSelected = controller.selectedCategory.value == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    cat,
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? const Color(0xff94A3B8) : const Color(0xff19335A)),
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
                                  backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
                                  side: BorderSide(
                                    color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                                  ),
                                  onSelected: (_) => controller.filterByCategory(cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Components List
              if (isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: accentColor),
                  ),
                )
              else
                Obx(() {
                  final components = controller.foundComponents;

                  if (components.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: isDark ? const Color(0xff475569) : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Components Found',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xffCBD5E1) : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try changing the category or search query.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final component = components[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: CAppTheme.cardDecoration(context, radius: 14),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: component.stock == 0
                                              ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.12))
                                              : component.stock <= 2
                                                  ? (isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.withOpacity(0.12))
                                                  : (isDark ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.12)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: component.stock == 0
                                                ? (isDark ? Colors.red.withOpacity(0.4) : Colors.transparent)
                                                : component.stock <= 2
                                                    ? (isDark ? Colors.orange.withOpacity(0.4) : Colors.transparent)
                                                    : (isDark ? Colors.green.withOpacity(0.4) : Colors.transparent),
                                          ),
                                        ),
                                        child: Text(
                                          component.stock == 0
                                              ? 'Out of Stock'
                                              : 'Stock: ${component.stock}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: component.stock == 0
                                                ? (isDark ? Colors.red[300] : Colors.red[800])
                                                : component.stock <= 2
                                                    ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                                    : (isDark ? Colors.green[300] : Colors.green[800]),
                                          ),
                                        ),
                                      ),
                                      if (component.boxNo.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Box: ${component.boxNo}',
                                            style: GoogleFonts.lato(
                                              fontSize: 12,
                                              color: secondaryText,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: secondaryText.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        },
                        childCount: components.length,
                      ),
                    ),
                  );
                }),
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
