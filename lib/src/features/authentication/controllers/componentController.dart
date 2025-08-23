import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/state_manager.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/microControllerList.dart';
import 'package:inventory/src/data/powercomponents.dart';
import 'package:inventory/src/data/sensors.dart';
import 'package:inventory/src/data/Communication Modules.dart';
import 'package:inventory/src/data/Actuators&Motors.dart';
import 'package:inventory/src/data/DisplaysandIndicators.dart';
import 'package:inventory/src/data/othermodulesandcomponents.dart';
import 'package:inventory/src/services/microcontroller_service.dart';
import 'package:inventory/src/services/powercomponent_service.dart';
import 'package:inventory/src/services/sensor_service.dart';
import 'package:inventory/src/services/communication_module_service.dart';
import 'package:inventory/src/services/actuator_motor_service.dart';
import 'package:inventory/src/services/display_indicator_service.dart';
import 'package:inventory/src/services/other_components_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComponentController extends GetxController {
  RxString Skuid = ''.obs;
  RxString CompName = ''.obs;
  RxString Boxname = ''.obs;
  RxString ClassName = ''.obs;
  RxInt Quantity = 1.obs;
  RxList<Cartcomponent> Cartcomponents = <Cartcomponent>[].obs;
  RxBool returnorissue = false.obs;
  RxString Status = ''.obs;

  TextEditingController namecontroller = TextEditingController();
  TextEditingController boxnocontroller = TextEditingController();
  RxList<Component> Classcomponents = <Component>[].obs;
  RxString title = ''.obs;
  RxString transactionid = ''.obs;

  // Database services for all component types
  final MicrocontrollerService _microcontrollerService =
      MicrocontrollerService();
  final PowercomponentService _powercomponentService = PowercomponentService();
  final SensorService _sensorService = SensorService();
  final CommunicationModuleService _communicationModuleService =
      CommunicationModuleService();
  final ActuatorMotorService _actuatorMotorService = ActuatorMotorService();
  final DisplayIndicatorService _displayIndicatorService =
      DisplayIndicatorService();
  final OtherComponentsService _otherComponentsService =
      OtherComponentsService();

  // Cache for all component data
  List<Component> _microcontrollerCache = [];
  List<Component> _powercomponentCache = [];
  List<Component> _sensorCache = [];
  List<Component> _communicationModuleCache = [];
  List<Component> _actuatorMotorCache = [];
  List<Component> _displayIndicatorCache = [];
  List<Component> _otherComponentsCache = [];

  // Cache loading states
  bool _microcontrollerCacheLoaded = false;
  bool _powercomponentCacheLoaded = false;
  bool _sensorCacheLoaded = false;
  bool _communicationModuleCacheLoaded = false;
  bool _actuatorMotorCacheLoaded = false;
  bool _displayIndicatorCacheLoaded = false;
  bool _otherComponentsCacheLoaded = false;

  // Loading states
  RxBool isLoadingMicrocontrollers = false.obs;
  RxBool isLoadingPowerComponents = false.obs;
  RxBool isLoadingSensors = false.obs;
  RxBool isLoadingCommunicationModules = false.obs;
  RxBool isLoadingActuatorMotors = false.obs;
  RxBool isLoadingDisplayIndicators = false.obs;
  RxBool isLoadingOtherComponents = false.obs;

  // Error states
  RxString microcontrollerError = ''.obs;
  RxString powerComponentError = ''.obs;
  RxString sensorError = ''.obs;
  RxString communicationModuleError = ''.obs;
  RxString actuatorMotorError = ''.obs;
  RxString displayIndicatorError = ''.obs;
  RxString otherComponentsError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(CompName, (_) {
      namecontroller.text = CompName.value;
    });
    ever(Boxname, (_) {
      boxnocontroller.text = Boxname.value;
    });

    // Listen to text controller changes and update the observables
    namecontroller.addListener(() {
      if (namecontroller.text != CompName.value) {
        CompName.value = namecontroller.text;
      }
    });

    boxnocontroller.addListener(() {
      if (boxnocontroller.text != Boxname.value) {
        Boxname.value = boxnocontroller.text;
      }
    });

    // Load all component data on initialization
    _loadAllComponentData();
  }

  // Load all component data from database
  Future<void> _loadAllComponentData() async {
    await Future.wait([
      _loadMicrocontrollerData(),
      _loadPowerComponentData(),
      _loadSensorData(),
      _loadCommunicationModuleData(),
      _loadActuatorMotorData(),
      _loadDisplayIndicatorData(),
      _loadOtherComponentsData(),
    ]);
  }

  // Load microcontroller data from database
  Future<void> _loadMicrocontrollerData() async {
    if (_microcontrollerCacheLoaded) return;

    try {
      isLoadingMicrocontrollers.value = true;
      microcontrollerError.value = '';

      _microcontrollerCache =
          await _microcontrollerService.getAllMicrocontrollers();
      _microcontrollerCacheLoaded = true;
      print(
          'Loaded ${_microcontrollerCache.length} microcontrollers from database');
    } catch (error) {
      print('Error loading microcontroller data: $error');
      microcontrollerError.value =
          'Failed to load microcontroller data: $error';
      _microcontrollerCache = [];
    } finally {
      isLoadingMicrocontrollers.value = false;
    }
  }

  // Load power component data from database
  Future<void> _loadPowerComponentData() async {
    if (_powercomponentCacheLoaded) return;

    try {
      isLoadingPowerComponents.value = true;
      powerComponentError.value = '';

      _powercomponentCache =
          await _powercomponentService.getAllPowercomponents();
      _powercomponentCacheLoaded = true;
      print(
          'Loaded ${_powercomponentCache.length} power components from database');
    } catch (error) {
      print('Error loading power component data: $error');
      powerComponentError.value = 'Failed to load power component data: $error';
      _powercomponentCache = [];
    } finally {
      isLoadingPowerComponents.value = false;
    }
  }

  // Load sensor data from database
  Future<void> _loadSensorData() async {
    if (_sensorCacheLoaded) return;

    try {
      isLoadingSensors.value = true;
      sensorError.value = '';

      _sensorCache = await _sensorService.getAllSensors();
      _sensorCacheLoaded = true;
      print('Loaded ${_sensorCache.length} sensors from database');
    } catch (error) {
      print('Error loading sensor data: $error');
      sensorError.value = 'Failed to load sensor data: $error';
      _sensorCache = [];
    } finally {
      isLoadingSensors.value = false;
    }
  }

  // Load communication module data from database
  Future<void> _loadCommunicationModuleData() async {
    if (_communicationModuleCacheLoaded) return;

    try {
      isLoadingCommunicationModules.value = true;
      communicationModuleError.value = '';

      _communicationModuleCache =
          await _communicationModuleService.getAllCommunicationModules();
      _communicationModuleCacheLoaded = true;
      print(
          'Loaded ${_communicationModuleCache.length} communication modules from database');
    } catch (error) {
      print('Error loading communication module data: $error');
      communicationModuleError.value =
          'Failed to load communication module data: $error';
      _communicationModuleCache = [];
    } finally {
      isLoadingCommunicationModules.value = false;
    }
  }

  // Load actuator motor data from database
  Future<void> _loadActuatorMotorData() async {
    if (_actuatorMotorCacheLoaded) return;

    try {
      isLoadingActuatorMotors.value = true;
      actuatorMotorError.value = '';

      _actuatorMotorCache =
          await _actuatorMotorService.getAllActuatorsAndMotors();
      _actuatorMotorCacheLoaded = true;
      print(
          'Loaded ${_actuatorMotorCache.length} actuator motors from database');
    } catch (error) {
      print('Error loading actuator motor data: $error');
      actuatorMotorError.value = 'Failed to load actuator motor data: $error';
      _actuatorMotorCache = [];
    } finally {
      isLoadingActuatorMotors.value = false;
    }
  }

  // Load display indicator data from database
  Future<void> _loadDisplayIndicatorData() async {
    if (_displayIndicatorCacheLoaded) return;

    try {
      isLoadingDisplayIndicators.value = true;
      displayIndicatorError.value = '';

      _displayIndicatorCache =
          await _displayIndicatorService.getAllDisplaysAndIndicators();
      _displayIndicatorCacheLoaded = true;
      print(
          'Loaded ${_displayIndicatorCache.length} display indicators from database');
    } catch (error) {
      print('Error loading display indicator data: $error');
      displayIndicatorError.value =
          'Failed to load display indicator data: $error';
      _displayIndicatorCache = [];
    } finally {
      isLoadingDisplayIndicators.value = false;
    }
  }

  // Load other components data from database
  Future<void> _loadOtherComponentsData() async {
    if (_otherComponentsCacheLoaded) return;

    try {
      isLoadingOtherComponents.value = true;
      otherComponentsError.value = '';

      _otherComponentsCache =
          await _otherComponentsService.getAllOtherComponents();
      _otherComponentsCacheLoaded = true;
      print(
          'Loaded ${_otherComponentsCache.length} other components from database');
    } catch (error) {
      print('Error loading other components data: $error');
      otherComponentsError.value =
          'Failed to load other components data: $error';
      _otherComponentsCache = [];
    } finally {
      isLoadingOtherComponents.value = false;
    }
  }

  void clearComponents() {
    Classcomponents.clear();
    print('ComponentController: All components cleared');
  }

  void addComponent(Component component) {
    // Check if component already exists based on skuId or name
    bool exists = Classcomponents.any((existingComponent) {
      // First try to match by skuId if both have it
      if (existingComponent.skuId != null && component.skuId != null) {
        return existingComponent.skuId!.trim() == component.skuId!.trim();
      }
      // Otherwise match by name (case-insensitive)
      return existingComponent.name.trim().toLowerCase() ==
          component.name.trim().toLowerCase();
    });

    if (!exists) {
      Classcomponents.add(component);
      print(
          'Added component: ${component.name} (${component.skuId}) - Stock: ${component.stock} - Total: ${Classcomponents.length}');
    } else {
      print(
          'Skipped duplicate component: ${component.name} (${component.skuId}) - Stock: ${component.stock}');
    }
  }

  // Add method to set components directly (replacing all existing ones)
  void setComponents(List<Component> components) {
    Classcomponents.clear();

    // Remove duplicates from the input list first
    final uniqueComponents = <Component>[];
    final seen = <String>{};

    for (final component in components) {
      // Use skuId as primary identifier, fall back to name
      final identifier =
          component.skuId?.trim() ?? component.name.trim().toLowerCase();

      if (!seen.contains(identifier)) {
        seen.add(identifier);
        uniqueComponents.add(component);
        print(
            'Adding unique component: ${component.name} (${component.skuId}) - Stock: ${component.stock}');
      } else {
        print(
            'Removing duplicate from input: ${component.name} (${component.skuId}) - Stock: ${component.stock}');
      }
    }

    Classcomponents.addAll(uniqueComponents);
    print(
        'Set ${uniqueComponents.length} unique components. Total in controller: ${Classcomponents.length}');
  }

  // Find component data from database by SKU ID and table name
  Future<Component?> _findComponentBySkuId(
      String skuId, String tableName) async {
    print('Looking for component with SKU: $skuId in table: $tableName');

    try {
      // Query the database directly
      final response = await Supabase.instance.client
          .from(tableName)
          .select('skuid, name, boxno, stock, warning')
          .eq('skuid', skuId)
          .maybeSingle();

      if (response != null) {
        final component = Component.fromJson(response);
        print('Found in database: ${component.name} (${component.skuId})');
        return component;
      } else {
        print('No component found in database for: $skuId');
        return null;
      }
    } catch (e) {
      print('Error querying database for component: $e');
      return null;
    }
  }

  // Find component in cache by SKU ID
  Component? _findComponentInCache(String skuId, List<Component> cache) {
    try {
      // First try exact match
      final exactMatch = cache.firstWhere(
        (component) =>
            component.skuId?.trim().toLowerCase() == skuId.trim().toLowerCase(),
        orElse: () => throw Exception('Not found'),
      );
      print('Exact match found: ${exactMatch.name} (${exactMatch.skuId})');
      return exactMatch;
    } catch (e) {
      print('No exact match found for: $skuId');
      return null;
    }
  }

  // Main SKU analysis method - now completely database-driven
  Future<void> skuidanalyze(String elem) async {
    print('Analyzing SKUID: $elem');

    // Microcontrollers (MC)
    if (RegExp(r'^MC').hasMatch(elem)) {
      ClassName.value = 'Microcontroller';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent =
          _findComponentInCache(elem, _microcontrollerCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent = await _findComponentBySkuId(elem, 'Microcontroller');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Microcontroller';
      Boxname.value = 'MC-00';
      Quantity.value = 0;
    }

    // Communication Modules (CM)
    else if (RegExp(r'^CM').hasMatch(elem)) {
      ClassName.value = 'Communication Modules';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent =
          _findComponentInCache(elem, _communicationModuleCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent =
          await _findComponentBySkuId(elem, 'Communication Modules');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Communication Module';
      Boxname.value = 'CM-00';
      Quantity.value = 0;
    }

    // Sensors (SN)
    else if (RegExp(r'^SN').hasMatch(elem)) {
      ClassName.value = 'Sensors';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent = _findComponentInCache(elem, _sensorCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent = await _findComponentBySkuId(elem, 'Sensors');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Sensor';
      Boxname.value = 'SN-00';
      Quantity.value = 0;
    }

    // Displays and Indicators (DI)
    else if (RegExp(r'^DI').hasMatch(elem)) {
      ClassName.value = 'Displays and Indicators';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent =
          _findComponentInCache(elem, _displayIndicatorCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent =
          await _findComponentBySkuId(elem, 'Displays and Indicators');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Display/Indicator';
      Boxname.value = 'DI-00';
      Quantity.value = 0;
    }

    // Actuators and Motors (AC)
    else if (RegExp(r'^AC').hasMatch(elem)) {
      ClassName.value = 'Actuators and Motors';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent = _findComponentInCache(elem, _actuatorMotorCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent =
          await _findComponentBySkuId(elem, 'Actuators and Motors');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Actuator/Motor';
      Boxname.value = 'AC-00';
      Quantity.value = 0;
    }

    // Power Components (PW)
    else if (RegExp(r'^PW').hasMatch(elem)) {
      ClassName.value = 'Power Components';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent = _findComponentInCache(elem, _powercomponentCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent = await _findComponentBySkuId(elem, 'Power Components');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Power Component';
      Boxname.value = 'PW-00';
      Quantity.value = 0;
    }

    // Others (any other prefix)
    else {
      ClassName.value = 'Others';
      print('ClassName set to: ${ClassName.value}');

      // Try to find in cache first
      final cachedComponent =
          _findComponentInCache(elem, _otherComponentsCache);
      if (cachedComponent != null) {
        CompName.value = cachedComponent.name;
        Boxname.value = cachedComponent.boxNo;
        Quantity.value = cachedComponent.stock;
        print(
            'Found in cache: ${cachedComponent.name} - Box: ${cachedComponent.boxNo} - Stock: ${cachedComponent.stock}');
        return;
      }

      // If not in cache, try database
      final dbComponent = await _findComponentBySkuId(elem, 'Others');
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Component';
      Boxname.value = 'OT-00';
      Quantity.value = 0;
    }
  }

  void reset() {
    Skuid.value = '';
    CompName.value = '';
    Boxname.value = '';
    Quantity.value = 1;
    namecontroller.clear();
    boxnocontroller.clear();
  }

  // Method to refresh all component data from database
  Future<void> refreshAllComponentData() async {
    _microcontrollerCacheLoaded = false;
    _powercomponentCacheLoaded = false;
    _sensorCacheLoaded = false;
    _communicationModuleCacheLoaded = false;
    _actuatorMotorCacheLoaded = false;
    _displayIndicatorCacheLoaded = false;
    _otherComponentsCacheLoaded = false;

    _microcontrollerCache.clear();
    _powercomponentCache.clear();
    _sensorCache.clear();
    _communicationModuleCache.clear();
    _actuatorMotorCache.clear();
    _displayIndicatorCache.clear();
    _otherComponentsCache.clear();

    await _loadAllComponentData();
  }

  // Method to check if stock is available
  bool isStockAvailable() {
    return Quantity.value > 0;
  }

  @override
  void onClose() {
    namecontroller.dispose();
    boxnocontroller.dispose();
    super.onClose();
  }
}
