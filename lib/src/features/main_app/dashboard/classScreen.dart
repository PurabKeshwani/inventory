import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/Actuators&Motors.dart';
import 'package:inventory/src/data/Communication%20Modules.dart';
import 'package:inventory/src/data/DisplaysandIndicators.dart';

import 'package:inventory/src/data/microControllerList.dart';

import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/powercomponents.dart';
import 'package:inventory/src/data/sensors.dart';
import 'package:inventory/src/data/othermodulesandcomponents.dart';
import 'package:inventory/src/features/main_app/components_in_class_screen/component_in_class_screen.dart';

import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/realtime_inventory_service.dart';
class Stock {
  int Stockval;

  Stock({required this.Stockval});
}

class Classscreen extends StatefulWidget {
  const Classscreen({required this.title, super.key});

  final String title;

  @override
  State<Classscreen> createState() => _ClassscreenState();
}

class _ClassscreenState extends State<Classscreen> {
  final ComponentController controller = Get.put(ComponentController(),
      tag: 'classscreen_${DateTime.now().millisecondsSinceEpoch}');
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool _isLoadingComponents = false;
  List<Component> _components = [];

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
      print("Realtime update received");
      await _loadComponents();
    },
  );
}

  Future<void> _loadComponents() async {
    // Prevent multiple simultaneous calls
    if (_isLoadingComponents) {
      print("_loadComponents already in progress, skipping");
      return;
    }

    print("_loadComponents called");
    _isLoadingComponents = true;

    setState(() {
      isLoading = true;
    });

    // Clear existing components before loading new ones
    controller.Classcomponents.clear();
    print(
        "Cleared existing components. Current count: ${controller.Classcomponents.length}");

    try {
      List<Component> componentList =
          await getComponentListbytitle(widget.title);
      print("Component list length: ${componentList.length}");

      if (componentList.isEmpty) {
        print("Warning: Component list is empty!");
      } else {
        // Debug: Print first few components from the list
        print("First few components from list:");
        for (int i = 0; i < componentList.length && i < 3; i++) {
          final comp = componentList[i];
          print("  $i: ${comp.name} (${comp.skuId}) - Stock: ${comp.stock}");
        }
      }

     final Map<String, Component> componentMap = {};
final Map<String, int> totalCountMap = {};
final Map<String, int> availableCountMap = {};

for (final component in componentList) {
  final key = component.name.trim().toLowerCase();

  componentMap.putIfAbsent(key, () => component);

  totalCountMap[key] = (totalCountMap[key] ?? 0) + 1;

  if (component.stock == 1) {
    availableCountMap[key] =
        (availableCountMap[key] ?? 0) + 1;
  }
}

final uniqueComponents = componentMap.entries.map((entry) {
  final key = entry.key;
  final component = entry.value;

   return Component(
  skuId: component.skuId,
  name: component.name,
  boxNo: component.boxNo,
  stock: totalCountMap[key]!,
  availableStock: availableCountMap[key] ?? 0,
  issuedStock:
      totalCountMap[key]! -
      (availableCountMap[key] ?? 0),
  warning: component.warning,
);
}).toList();

      // Debug: Print final grouped components
      print("Final grouped components:");
      for (final comp in uniqueComponents) {
        print("  ${comp.name} - Total Stock: ${comp.stock}");
      }

      _components = uniqueComponents;
      controller.setComponents(uniqueComponents);

      print(
          "Final component count in controller: ${controller.Classcomponents.length}");
    } catch (error) {
      print("Error loading components: $error");
    }

    setState(() {
      isLoading = false;
    });

    _isLoadingComponents = false;
  }

  Future<List<Component>> getComponentListbytitle(String title) async {
    print("Fetching components for title: $title");
    String normalizedTitle = title.trim();
    print("Normalized title: $normalizedTitle");

    // Convert to lowercase for case-insensitive comparison
    switch (normalizedTitle.toLowerCase()) {
      case 'microcontroller':
        return await Microcontrollers().getComponents();
      case 'communication modules':
        return CommunicationModules().getComponents();
      case 'sensors':
        return await Sensors().getComponents();
      case 'displays and indicators':
        return await Displaysandindicators().getComponents();

      case 'actuators and motors':
        return await ActuatorsandMotors().getComponents();

      case 'power components':
        return await Powercomponents().getComponents();
      case 'others':
        print("Fetching components for 'others' category");
        try {
          final components = await Othermodulesandcomponents().getComponents();
          print(
              "Successfully fetched ${components.length} components for 'others'");
          return components;
        } catch (error) {
          print("Error fetching 'others' components: $error");
          return [];
        }
      default:
        print("WARNING: No match found for title: '$normalizedTitle'");
        return [];
    }
  }

  Future<int> getStock(String componentName) async {
    try {
      // Map the widget title to the correct table name
      String tableName = getTableNameByTitle(widget.title);
      print(
          "getStock: Using table name: '$tableName' for component: '$componentName'");

      final totalitems = await supabase
          .from(tableName)
          .select('stock')
          .eq('name', componentName);

      final stockItems =
          totalitems.map((item) => Stock(Stockval: item['stock'])).toList();

      var tot = 0;
      for (var item in stockItems) {
        tot = tot + item.Stockval;
      }

      return tot;
    } catch (error) {
      print('Error fetching stock for $componentName: $error');
      return 0;
    }
  }

  String getTableNameByTitle(String title) {
    String normalizedTitle = title.trim().toLowerCase();
    print(
        "getTableNameByTitle called with: '$title' -> normalized: '$normalizedTitle'");

    switch (normalizedTitle) {
      case 'microcontroller':
        return 'Microcontroller';
      case 'communication modules':
        return 'CommunicationModules'; // Adjust based on your actual table name
      case 'sensors':
        return 'Sensors'; // Adjust based on your actual table name
      case 'displays and indicators':
        return 'DisplaysAndIndicators'; // Adjust based on your actual table name
      case 'actuators and motors':
        return 'ActuatorsAndMotors'; // Adjust based on your actual table name
      case 'audio modules':
        return 'AudioModules'; // Adjust based on your actual table name
      case 'connectors and switches':
        return 'ConnectorsAndSwitches'; // Adjust based on your actual table name
      case 'power components':
        return 'Power Components'; // Fixed: Use the actual table name with space
      case 'others':
        return 'Others'; // Add mapping for Others table
      default:
        return title; // Fallback to original title
    }
  }

  List<String> parseBoxNumbers(String boxNo) {
    if (boxNo.isEmpty) return [];
    return boxNo
        .split(',')
        .map((box) => box.trim())
        .where((box) => box.isNotEmpty)
        .toList();
  }

  Widget buildBoxNumberText(List<String> boxNumbers) {
    if (boxNumbers.isEmpty) return const Text('No box numbers');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        boxNumbers.join(', '),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
    @override
void dispose() {
  if (channel != null) {
    Supabase.instance.client.removeChannel(channel!);
  }

  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Theme(
          data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: Colors.black54),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: const Color(0xffC5E3FF),
        title: Text(
          widget.title,
          style: GoogleFonts.lato(color: Colors.black),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 154, 210, 255),
              Color.fromARGB(255, 213, 245, 252),
              Color.fromARGB(255, 242, 254, 255)
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : ListView.builder(
                  itemCount: _components.length,
                  itemBuilder: (context, index) {
                    final component = _components[index];
                    print("Rendering component: ${component.name}");

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(
                          component.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Box Numbers: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                                Expanded(
                                  child: buildBoxNumberText(
                                      parseBoxNumbers(component.boxNo)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                               Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: component.stock == 0
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : component.stock <= 2
                                            ? Colors.orange.withValues(alpha: 0.15)
                                            : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Stock: ${component.stock}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: component.stock == 0
                                          ? Colors.red
                                          : component.stock <= 2
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 5),

                                 const SizedBox(width: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Available: ${component.availableStock}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Issued: ${component.issuedStock}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Get.to(() =>
                              ComponentInClassScreen(component: component));
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
