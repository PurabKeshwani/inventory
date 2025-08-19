import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/data/Actuators&Motors.dart';
import 'package:inventory/src/data/Communication%20Modules.dart';
import 'package:inventory/src/data/DisplaysandIndicators.dart';

import 'package:inventory/src/data/microControllerList.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/sensors.dart';
import 'package:inventory/src/features/main_app/components_in_class_screen/component_in_class_screen.dart';

class Componentcontroller extends GetxController {
  RxList<Component> components = <Component>[].obs;
  RxList<Component> foundComponents = <Component>[].obs;

  @override
  void onInit() {
    super.onInit();
    foundComponents.value = components;
  }

  void addComponent(Component component) {
    components.add(component);
    foundComponents.add(component);
  }

  void filterComponents(String query) {
    if (query.isEmpty) {
      foundComponents.value = components;
    } else {
      foundComponents.value = components
          .where((component) =>
              component.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final Componentcontroller controller = Get.put(Componentcontroller());
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller.components.clear();
    _loadAllComponents();
  }

  Future<void> _loadAllComponents() async {
    setState(() {
      isLoading = true;
    });

    // Clear existing components
    controller.components.clear();
    controller.foundComponents.clear();
    print(
        "Cleared existing components in search. Current count: ${controller.components.length}");

    List<Component> componentList = await getAllComponents();
    print("Total components fetched for search: ${componentList.length}");

    for (Component elem in componentList) {
      controller.addComponent(elem);
    }

    print(
        "Final component count in search controller: ${controller.components.length}");

    setState(() {
      isLoading = false;
    });
  }

  Future<List<Component>> getAllComponents() async {
    // Get microcontrollers from Supabase
    final microcontrollers = await Microcontrollers().getComponents();
    final communicationmodules = await CommunicationModules().getComponents();
    final actuatorsandmotors = await ActuatorsandMotors().getComponents();
    final displaysandindicators = await Displaysandindicators().getComponents();
    final sensors = await Sensors().getComponents();

    return [
      ...microcontrollers,
      ...communicationmodules,
      ...sensors,
      ...displaysandindicators,
      ...actuatorsandmotors,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Component Search'),
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
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => controller.filterComponents(value),
                decoration: const InputDecoration(
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAllComponents,
                        child: Obx(
                          () => ListView.builder(
                            cacheExtent: 400,
                            itemCount: controller.foundComponents.length,
                            itemBuilder: (context, index) {
                              final component =
                                  controller.foundComponents[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                ComponentInClassScreen(
                                                    component: component)));
                                  },
                                  title: Text(
                                    component.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Box No: ${component.boxNo}\nStock: ${component.stock}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
