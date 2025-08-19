import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/state_manager.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/data/microControllerList.dart';
import 'package:inventory/src/data/powercomponents.dart';

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

  // Database service for microcontrollers
  final Microcontrollers _microcontrollers = Microcontrollers();

  // Database service for power components
  final Powercomponents _powercomponents = Powercomponents();

  // Cache for microcontroller data
  List<Component> _microcontrollerCache = [];
  bool _cacheLoaded = false;

  // Cache for power component data
  List<Component> _powercomponentCache = [];
  bool _powerCacheLoaded = false;

  // Loading states
  RxBool isLoadingMicrocontrollers = false.obs;
  RxString microcontrollerError = ''.obs;
  RxBool isLoadingPowerComponents = false.obs;
  RxString powerComponentError = ''.obs;

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

    // Load microcontroller data on initialization
    _loadMicrocontrollerData();

    // Load power component data on initialization
    _loadPowerComponentData();
  }

  // Load microcontroller data from database
  Future<void> _loadMicrocontrollerData() async {
    if (_cacheLoaded) return;

    try {
      isLoadingMicrocontrollers.value = true;
      microcontrollerError.value = '';

      _microcontrollerCache = await _microcontrollers.getComponents();
      _cacheLoaded = true;
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
    if (_powerCacheLoaded) return;

    try {
      isLoadingPowerComponents.value = true;
      powerComponentError.value = '';

      _powercomponentCache = await _powercomponents.getComponents();
      _powerCacheLoaded = true;
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

  // Find microcontroller data from database using pattern matching
  Component? _findMicrocontrollerBySkuId(String skuId) {
    print('Looking for microcontroller with SKU: $skuId');

    try {
      // First try exact match
      final exactMatch = _microcontrollerCache.firstWhere(
        (component) =>
            component.skuId?.trim().toLowerCase() == skuId.trim().toLowerCase(),
        orElse: () => throw Exception('Not found'),
      );
      print('Exact match found: ${exactMatch.name} (${exactMatch.skuId})');
      return exactMatch;
    } catch (e) {
      print('No exact match found, trying pattern matching...');
      // If exact match fails, try pattern matching
      final patternMatch = _findMicrocontrollerByPattern(skuId);
      if (patternMatch != null) {
        print(
            'Pattern match successful: ${patternMatch.name} (${patternMatch.skuId})');
      } else {
        print('No pattern match found for: $skuId');
      }
      return patternMatch;
    }
  }

  // Find power component data from database using pattern matching
  Component? _findPowerComponentBySkuId(String skuId) {
    print('Looking for power component with SKU: $skuId');

    try {
      // First try exact match
      final exactMatch = _powercomponentCache.firstWhere(
        (component) =>
            component.skuId?.trim().toLowerCase() == skuId.trim().toLowerCase(),
        orElse: () => throw Exception('Not found'),
      );
      print('Exact match found: ${exactMatch.name} (${exactMatch.skuId})');
      return exactMatch;
    } catch (e) {
      print('No exact match found, trying pattern matching...');
      // If exact match fails, try pattern matching
      final patternMatch = _findPowerComponentByPattern(skuId);
      if (patternMatch != null) {
        print(
            'Pattern match successful: ${patternMatch.name} (${patternMatch.skuId})');
      } else {
        print('No pattern match found for: $skuId');
      }
      return patternMatch;
    }
  }

  // Find microcontroller by pattern matching (e.g., MC-ARD-UNO-016 matches MC-ARD-UNO-015)
  Component? _findMicrocontrollerByPattern(String skuId) {
    try {
      final inputSkuLower = skuId.trim().toLowerCase();
      print('Pattern matching for input: $inputSkuLower');
      print('Cache has ${_microcontrollerCache.length} components');

      // Extract base pattern from input (remove trailing numbers)
      // MC-ARD-UNO-016 -> MC-ARD-UNO
      final inputBase = inputSkuLower.replaceAll(RegExp(r'-\d+$'), '');
      print('Input base pattern: $inputBase');

      Component? bestMatch;

      for (final component in _microcontrollerCache) {
        final dbSkuLower = component.skuId?.trim().toLowerCase();
        if (dbSkuLower == null) continue;

        print('Checking database SKU: $dbSkuLower');

        // Extract base pattern from database SKU
        // MC-ARD-UNO-015 -> MC-ARD-UNO
        final dbBase = dbSkuLower.replaceAll(RegExp(r'-\d+$'), '');
        print('Database base pattern: $dbBase');

        // Check if base patterns match
        if (inputBase == dbBase && inputBase.isNotEmpty) {
          bestMatch = component;
          print(
              '✅ Pattern match found: $inputSkuLower -> $dbSkuLower (base: $inputBase)');
          break;
        }

        // Also check if database SKU is a prefix of input SKU (for cases without numbers)
        if (inputSkuLower.startsWith(dbSkuLower + '-')) {
          bestMatch = component;
          print('✅ Prefix match found: $inputSkuLower -> $dbSkuLower');
          break;
        }

        // Additional check: if input starts with database base pattern
        if (inputSkuLower.startsWith(dbBase + '-') && dbBase.isNotEmpty) {
          bestMatch = component;
          print(
              '✅ Base prefix match found: $inputSkuLower -> $dbSkuLower (base: $dbBase)');
          break;
        }
      }

      if (bestMatch == null) {
        print('❌ No pattern match found for: $skuId');
        // Debug: Print all available SKUs for troubleshooting
        print('Available SKUs in cache:');
        for (final component in _microcontrollerCache) {
          print('  - ${component.skuId} (${component.name})');
        }
      }

      return bestMatch;
    } catch (e) {
      print('Error in pattern matching: $e');
      return null;
    }
  }

  // Find power component by pattern matching (e.g., PW-VOLT-REG-016 matches PW-VOLT-REG-015)
  Component? _findPowerComponentByPattern(String skuId) {
    try {
      final inputSkuLower = skuId.trim().toLowerCase();
      print('Pattern matching for power component input: $inputSkuLower');
      print('Power cache has ${_powercomponentCache.length} components');

      // Extract base pattern from input (remove trailing numbers)
      // PW-VOLT-REG-016 -> PW-VOLT-REG
      final inputBase = inputSkuLower.replaceAll(RegExp(r'-\d+$'), '');
      print('Input base pattern: $inputBase');

      Component? bestMatch;

      for (final component in _powercomponentCache) {
        final dbSkuLower = component.skuId?.trim().toLowerCase();
        if (dbSkuLower == null) continue;

        print('Checking database SKU: $dbSkuLower');

        // Extract base pattern from database SKU
        // PW-VOLT-REG-015 -> PW-VOLT-REG
        final dbBase = dbSkuLower.replaceAll(RegExp(r'-\d+$'), '');
        print('Database base pattern: $dbBase');

        // Check if base patterns match
        if (inputBase == dbBase && inputBase.isNotEmpty) {
          bestMatch = component;
          print(
              '✅ Pattern match found: $inputSkuLower -> $dbSkuLower (base: $inputBase)');
          break;
        }

        // Also check if database SKU is a prefix of input SKU (for cases without numbers)
        if (inputSkuLower.startsWith(dbSkuLower + '-')) {
          bestMatch = component;
          print('✅ Prefix match found: $inputSkuLower -> $dbSkuLower');
          break;
        }

        // Additional check: if input starts with database base pattern
        if (inputSkuLower.startsWith(dbBase + '-') && dbBase.isNotEmpty) {
          bestMatch = component;
          print(
              '✅ Base prefix match found: $inputSkuLower -> $dbSkuLower (base: $dbBase)');
          break;
        }
      }

      if (bestMatch == null) {
        print('❌ No pattern match found for power component: $skuId');
        // Debug: Print all available SKUs for troubleshooting
        print('Available power component SKUs in cache:');
        for (final component in _powercomponentCache) {
          print('  - ${component.skuId} (${component.name})');
        }
      }

      return bestMatch;
    } catch (e) {
      print('Error in power component pattern matching: $e');
      return null;
    }
  }

  // Async version of skuidanalyze that ensures data is loaded
  Future<void> skuidanalyzeAsync(String elem) async {
    print('=== STARTING ASYNC SKU ANALYSIS ===');
    print('Input SKU: $elem');

    // Ensure microcontroller data is loaded
    if (!_cacheLoaded) {
      print('Cache not loaded, loading microcontroller data...');
      await _loadMicrocontrollerData();
    } else {
      print(
          'Cache already loaded with ${_microcontrollerCache.length} components');
    }

    // Ensure power component data is loaded
    if (!_powerCacheLoaded) {
      print('Power cache not loaded, loading power component data...');
      await _loadPowerComponentData();
    } else {
      print(
          'Power cache already loaded with ${_powercomponentCache.length} components');
    }

    // Debug: Print cache contents for troubleshooting
    debugPrintCache();

    // Now call the regular analyze method
    skuidanalyze(elem);

    print('=== FINISHED ASYNC SKU ANALYSIS ===');
  }

  void skuidanalyze(String elem) {
    print('Analyzing SKUID: $elem');
    if (RegExp(r'^MC').hasMatch(elem)) {
      ClassName.value = 'Microcontroller';
      print('ClassName set to: ${ClassName.value}');

      // Try to find the component in the database using pattern matching
      final dbComponent = _findMicrocontrollerBySkuId(elem);
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found in database, set default values
      print('Not found in database: $elem');
      CompName.value = 'Unknown Microcontroller';
      Boxname.value = 'MC-00';
      Quantity.value = 0;
    } else if (RegExp(r'^SN').hasMatch(elem)) {
      ClassName.value = 'Sensors';
      if (RegExp(r'SN-SHARP-IR').hasMatch(elem)) {
        CompName.value = 'Sharp I.R sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-DHT11-TH').hasMatch(elem)) {
        CompName.value = 'DHT11 (Temperature and humidity sensor)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-SOIL-MOD').hasMatch(elem)) {
        CompName.value = 'Soil Sensor (with module)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-RCWL-MWR').hasMatch(elem)) {
        CompName.value = 'Microwave Radar Sensor (RCWL-0516)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-HCSR04-ULT').hasMatch(elem)) {
        CompName.value = 'Ultrasonic (HC-SR04)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-PHOTO-IR').hasMatch(elem)) {
        CompName.value = 'IR SENSOR (photo diode)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-PIR-SENS').hasMatch(elem)) {
        CompName.value = 'PIR sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-GAS-SENS').hasMatch(elem)) {
        CompName.value = 'Gas sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-HALL-EFF').hasMatch(elem)) {
        CompName.value = 'Hall effect sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-ADXL345-ACC').hasMatch(elem)) {
        CompName.value = 'Accelerometer (adxl345) (GY521)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-MPU9265-GYR').hasMatch(elem)) {
        CompName.value = 'Gyroscope (MPU92.65)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-IR-RECV').hasMatch(elem)) {
        CompName.value = 'IR infrared receiver';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-SN103810-IR').hasMatch(elem)) {
        CompName.value = 'IR SENSOR SN103810';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-MPXV5').hasMatch(elem)) {
        CompName.value = 'pressure sensor (MPXV5100DP)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LDR-MOD').hasMatch(elem)) {
        CompName.value = 'LDR Module';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LDR').hasMatch(elem)) {
        CompName.value = 'LDR Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-CLR').hasMatch(elem)) {
        CompName.value = 'Colour sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-APD-9930').hasMatch(elem)) {
        CompName.value = 'APD-9930 Proximity Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-IR-ARR').hasMatch(elem)) {
        CompName.value = 'IR sensor array';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-FLEX').hasMatch(elem)) {
        CompName.value = 'Flex Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-FORCE').hasMatch(elem)) {
        CompName.value = 'Force sensitive sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-PELT').hasMatch(elem)) {
        CompName.value = 'Peltier module';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-DOP-RDR').hasMatch(elem)) {
        CompName.value = 'Doppler radar sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-ECG').hasMatch(elem)) {
        CompName.value = 'ECG patches';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LDCL-40').hasMatch(elem)) {
        CompName.value = 'Load Cell (40 kg)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LDCL-5').hasMatch(elem)) {
        CompName.value = 'Load Cell (5 kg)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-MLX90640').hasMatch(elem)) {
        CompName.value = 'Thermopile Array (MLX90640)';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LIDAR').hasMatch(elem)) {
        CompName.value = 'RP-Lidar Sensor';
        Boxname.value = 'SN-01';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LIDAR-COMMON').hasMatch(elem)) {
        CompName.value = 'RP-Lidar AM-18';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-TTL-FTDI').hasMatch(elem)) {
        CompName.value = 'FTDI';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-VL53L0x-LIDAR').hasMatch(elem)) {
        CompName.value = '1D LIDAR';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-AHT-10').hasMatch(elem)) {
        CompName.value = 'Temperature Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-RGB-COLOR').hasMatch(elem)) {
        CompName.value = 'RGB SENSOR';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-RAIN').hasMatch(elem)) {
        CompName.value = 'RAIN DROP SENSOR';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-NTC').hasMatch(elem)) {
        CompName.value = 'NTC COMMON';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-MQ135').hasMatch(elem)) {
        CompName.value = 'Smoke Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LASER-REC').hasMatch(elem)) {
        CompName.value = 'Laser Receiver';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LASER-MOD').hasMatch(elem)) {
        CompName.value = 'Laser Module';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-RFID').hasMatch(elem)) {
        CompName.value = 'RFID Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-IR-REC-COMMON').hasMatch(elem)) {
        CompName.value = 'IR Receiver';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-LINE-FOLLOW').hasMatch(elem)) {
        CompName.value = 'Line Follow Sensor';
        Boxname.value = 'SN-01';
      } else if (RegExp(r'SN-METAL').hasMatch(elem)) {
        CompName.value = 'Metal Sensor';
        Boxname.value = 'SN-01';
      }
    } else if (RegExp(r'^CM').hasMatch(elem)) {
      ClassName.value = 'Communication Modules';
      if (RegExp(r'CM-AUBTM-BT').hasMatch(elem)) {
        CompName.value = 'AUBTM 20 Bluetooth module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-ETH-MOD').hasMatch(elem)) {
        CompName.value = 'Ethernet Module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-SC05-BT').hasMatch(elem)) {
        CompName.value = 'SC05 Bluetooth module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-TTL-RS485').hasMatch(elem)) {
        CompName.value = 'TTL TO RS485';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-SIM-GSM').hasMatch(elem)) {
        CompName.value = 'SIM 800A/900A GSM MODULE';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-GSM-6M').hasMatch(elem)) {
        CompName.value = 'GSM 6M MODULE';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-XBEE-PRO').hasMatch(elem)) {
        CompName.value = 'Xbee pro';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-NRF24-ANT').hasMatch(elem)) {
        CompName.value = 'NRF 24201 (with antenna)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-CP2102-UART').hasMatch(elem)) {
        CompName.value = 'Arduino port to UART(SYLABS CP2102)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-WIFI-RLY').hasMatch(elem)) {
        CompName.value = 'Wifi Relay';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-R315A-MOD').hasMatch(elem)) {
        CompName.value = 'R315A Transmitter-Receiver module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'esp 32 wifi module').hasMatch(elem)) {
        CompName.value = 'ESP32 wifi module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-XBEE-USB').hasMatch(elem)) {
        CompName.value = 'ZIGBEE usb';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-EM18').hasMatch(elem)) {
        CompName.value = 'reader module(EM-18)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-GPS-NEO6M').hasMatch(elem)) {
        CompName.value = 'GPS Module (gy-neo6mv2)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-NRF24-LO1').hasMatch(elem)) {
        CompName.value = 'NRF24 L01 without antenna';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-GPS-ANT').hasMatch(elem)) {
        CompName.value = 'GPS Antenna';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-ZIG-N26').hasMatch(elem)) {
        CompName.value = 'zigbee mesh (N26000)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'NRF 24LD1 (Without Antenna)').hasMatch(elem)) {
        CompName.value = 'NRF 24LD1 (Without Antenna)';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-GPS-NEO6M').hasMatch(elem)) {
        CompName.value = 'ESp 01 wifi module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-RFID').hasMatch(elem)) {
        CompName.value = 'RFID module';
        Boxname.value = 'CM-01';
      } else if (RegExp(r'CM-GPS-MOD').hasMatch(elem)) {
        CompName.value = 'GPS Module';
        Boxname.value = 'CM-01';
      }
    } else if (RegExp(r'^AC').hasMatch(elem)) {
      ClassName.value = 'Actuators and Motors';
      if (RegExp(r'AC-SERVO-MTR').hasMatch(elem)) {
        //check
        CompName.value = 'Servo motors';
        Boxname.value = 'AC-01';
      } else if (RegExp(r'AC-L9110-DRV').hasMatch(elem)) {
        CompName.value = 'L9110 Motor driver';
        Boxname.value = 'AC-04';
      } else if (RegExp(r'AC-GEAR-MTR-DRV').hasMatch(elem)) {
        CompName.value = 'Gear Motor Driver 5V';
        Boxname.value = 'AC-02';
      } else if (RegExp(r'AC-SLND-LCK').hasMatch(elem)) {
        CompName.value = 'Solenoid Lock';
        Boxname.value = 'AC-03';
      } else if (RegExp(r'AC-RLY-MOD1').hasMatch(elem)) {
        CompName.value = 'Relay module';
        Boxname.value = 'AC-06';
      } else if (RegExp(r'AC-RLY-MOD2').hasMatch(elem)) {
        CompName.value = 'Relay module';
        Boxname.value = 'AC-01';
      } else if (RegExp(r'AC-RLY-SSR').hasMatch(elem)) {
        CompName.value = 'Solid state Relay';
        Boxname.value = 'AC-01';
      } else if (RegExp(r'AC-MTR-5V').hasMatch(elem)) {
        CompName.value = '5V Motor';
        Boxname.value = 'AC-01';
      } else if (RegExp(r'AC-MTR-612V').hasMatch(elem)) {
        CompName.value = '5-12V Motor';
        Boxname.value = 'AC-01';
      } else if (RegExp(r'AC-N20-MTR').hasMatch(elem)) {
        CompName.value = 'N20 Encoded DC Motor';
        Boxname.value = 'AC-02';
      } else if (RegExp(r'AC-SOLENOID-PUMP').hasMatch(elem)) {
        CompName.value = 'Solenoid Pump';
        Boxname.value = 'AC-02';
      } else if (RegExp(r'AC-MTR-L298').hasMatch(elem)) {
        CompName.value = 'L298 Driver';
        Boxname.value = 'AC-02';
      } else if (RegExp(r'AC-STEPPER-DRIVER').hasMatch(elem)) {
        CompName.value = 'Stepper Motor Driver';
        Boxname.value = 'AC-02';
      }
    } else if (RegExp(r'^DI').hasMatch(elem)) {
      ClassName.value = 'Displays and Indicators';
      if (RegExp(r'DI-SMALL-OLED').hasMatch(elem)) {
        CompName.value = 'Small O-LED';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-8DIG-7SEG').hasMatch(elem)) {
        CompName.value = '8 digit 7 segment display';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-2DIG-7SEG-RED').hasMatch(elem)) {
        CompName.value = '2 digit 7 segment (red colour)';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-1DIG-7SEG-BIG').hasMatch(elem)) {
        CompName.value = '1 digit 7 segment display (Big)';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-1DIG-7SEG').hasMatch(elem)) {
        CompName.value = '1 digit 7 segment display';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-3DIG-7SEG').hasMatch(elem)) {
        CompName.value = '3 digit 7 segment';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-LED-MATRIX').hasMatch(elem)) {
        CompName.value = 'LED matrix';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-RGB-STRIP').hasMatch(elem)) {
        CompName.value = 'RGB LED STRIPS';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-SSD1306-IIC').hasMatch(elem)) {
        CompName.value = 'IIC OLED SSD1306';
        Boxname.value = 'DI-01';
      } else if (RegExp(r'DI-I2C-MOD').hasMatch(elem)) {
        CompName.value = 'I2C MODULE';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-LCD-SH').hasMatch(elem)) {
        CompName.value = 'LCD with sheild';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-LCD16').hasMatch(elem)) {
        CompName.value = 'LCD 16X2';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-LCD-20').hasMatch(elem)) {
        CompName.value = 'LCD 20 x 4';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-RFID-TAG').hasMatch(elem)) {
        CompName.value = 'RFID TAG';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-RFID-CARD').hasMatch(elem)) {
        CompName.value = 'RFID CARD';
        Boxname.value = 'DI-02';
      } else if (RegExp(r'DI-LCD-3508').hasMatch(elem)) {
        CompName.value = 'LCD 3.5 inch';
        Boxname.value = 'DI-02';
      }
    } else if (RegExp(r'^AM').hasMatch(elem)) {
      ClassName.value = 'Audio Modules';
      if (RegExp(r'AM-WT588D-16P').hasMatch(elem)) {
        CompName.value = 'WT588D-16PV1.1';
        Boxname.value = 'AM-01';
      } else if (RegExp(r'AM-WT588D-VOICE').hasMatch(elem)) {
        CompName.value = 'Voice sound module (WT588D)';
        Boxname.value = 'AM-01';
      } else if (RegExp(r'AM-VOICE-REC-MIC').hasMatch(elem)) {
        CompName.value = 'Voice recognition module (with mic)';
        Boxname.value = 'AM-01';
      } else if (RegExp(r'AM-PCB-SPEAKER').hasMatch(elem)) {
        CompName.value = 'PCB mount mini Speaker';
        Boxname.value = 'AM-01';
      } else if (RegExp(r'AM-MP3V5050G').hasMatch(elem)) {
        CompName.value = 'MP3V5050g';
        Boxname.value = 'AM-01';
      }
    } else if (RegExp(r'^IC').hasMatch(elem)) {
      ClassName.value = 'ICs and Semiconductors';
      if (RegExp(r'IC-LM324').hasMatch(elem)) {
        CompName.value = 'LM324N, LM324';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-P9624AB').hasMatch(elem)) {
        CompName.value = 'P9624AB';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-HD74LS00P').hasMatch(elem)) {
        CompName.value = 'HD74LSOOP';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-74LV04N').hasMatch(elem)) {
        CompName.value = '74LV04SN, 74LV04N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-7483').hasMatch(elem)) {
        CompName.value = '7483 IC';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-74147').hasMatch(elem)) {
        CompName.value = '74147 IC';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-MM74HC138N').hasMatch(elem)) {
        CompName.value = 'MM74HC138N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-CD74HC573E').hasMatch(elem)) {
        CompName.value = 'CD74HC573E';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-OPAMP-741').hasMatch(elem)) {
        CompName.value = 'OP-AMP 741 IC';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-NE555').hasMatch(elem)) {
        CompName.value = 'NE555 IC';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-MAX-ULC').hasMatch(elem)) {
        CompName.value = 'Max 232 ULN 2803 16 PIN CONNECTOR';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-75ACOLM').hasMatch(elem)) {
        CompName.value = 'IC 75ACOLM';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-766').hasMatch(elem)) {
        CompName.value = 'IC 7660';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-DS1302').hasMatch(elem)) {
        CompName.value = 'DS1302';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-AD1674').hasMatch(elem)) {
        CompName.value = 'AD1674';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-ENC28J60').hasMatch(elem)) {
        CompName.value = 'ENC28J60';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-HD74LS32P').hasMatch(elem)) {
        CompName.value = 'HD74LS32P';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-HD74LS08P').hasMatch(elem)) {
        CompName.value = 'HD74LS08P';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-L293DNE').hasMatch(elem)) {
        CompName.value = 'L293DNE';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-L293D').hasMatch(elem)) {
        CompName.value = 'L293D';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-DM74').hasMatch(elem)) {
        CompName.value = 'DM74LS123N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-MM74').hasMatch(elem)) {
        CompName.value = 'MM74HC138N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-M74HC').hasMatch(elem)) {
        CompName.value = 'M74HC59581';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-SN74').hasMatch(elem)) {
        CompName.value = 'SN74LS32N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-CD40').hasMatch(elem)) {
        CompName.value = 'CD4017BE';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-779').hasMatch(elem)) {
        CompName.value = 'CD74HC573E';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-780').hasMatch(elem)) {
        CompName.value = 'ULN2803APG';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-785').hasMatch(elem)) {
        CompName.value = 'NE555P';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-786').hasMatch(elem)) {
        CompName.value = 'SN75176BP';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-787').hasMatch(elem)) {
        CompName.value = 'Hw221 logic level converter';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-788').hasMatch(elem)) {
        CompName.value = 'SN74LS83N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-789').hasMatch(elem)) {
        CompName.value = '74LV04NC9155PS';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-790').hasMatch(elem)) {
        CompName.value = 'DM74LS20N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-791').hasMatch(elem)) {
        CompName.value = 'OP07CP';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-792').hasMatch(elem)) {
        CompName.value = '3201-B';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-793').hasMatch(elem)) {
        CompName.value = 'LM7812C';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-794').hasMatch(elem)) {
        CompName.value = 'IRF540';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-795').hasMatch(elem)) {
        CompName.value = 'UA74C1';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-796').hasMatch(elem)) {
        CompName.value = 'AD820N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-797').hasMatch(elem)) {
        CompName.value = 'MH741CNKD8437';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-798').hasMatch(elem)) {
        CompName.value = 'LM386N';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-799').hasMatch(elem)) {
        CompName.value = 'QP07CP';
        Boxname.value = 'IC-01';
      } else if (RegExp(r'IC-800').hasMatch(elem)) {
        CompName.value = 'AD1674KN';
        Boxname.value = 'IC-01';
      }
    } else if (RegExp(r'^PC').hasMatch(elem)) {
      ClassName.value = 'Passive Components';
      if (RegExp(r'PC-POT-XXX').hasMatch(elem)) {
        CompName.value = 'Potentiometers';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-CAP-ELC').hasMatch(elem)) {
        CompName.value = 'Capacitor electrolytic';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-CAP-CR').hasMatch(elem)) {
        CompName.value = 'Capacitor ceramic';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-CAP-PP').hasMatch(elem)) {
        CompName.value = 'Capacitor polypropylene';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-IND-AXL').hasMatch(elem)) {
        CompName.value = 'Inductor axial';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-RES').hasMatch(elem)) {
        CompName.value = 'Resistor';
        Boxname.value = 'PC-01';
      } else if (RegExp(r'PC-LM317').hasMatch(elem)) {
        CompName.value = 'LM317';
        Boxname.value = 'PC-01';
      }
    } else if (RegExp(r'^CS').hasMatch(elem) || RegExp(r'^OM').hasMatch(elem)) {
      ClassName.value = 'Connectors and Switches';
      if (RegExp(r'CS-LUGS').hasMatch(elem)) {
        CompName.value = 'Lugs';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-28PIN-RD-DIP').hasMatch(elem)) {
        CompName.value = '28 pin IC base';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-16PIN-RD-DIP').hasMatch(elem)) {
        CompName.value = '16 pin IC base';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-18PIN-RD-DIP').hasMatch(elem)) {
        CompName.value = '18 pin IC base';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-14PIN-RD-DIP').hasMatch(elem)) {
        CompName.value = '14 pin IC base';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-DC-JACK').hasMatch(elem)) {
        CompName.value = 'DC Jack';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-PUSH-BTN').hasMatch(elem)) {
        CompName.value = 'Push buttons';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-LEVER-SW').hasMatch(elem)) {
        CompName.value = 'Lever Switch';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-DPI-SW').hasMatch(elem)) {
        CompName.value = 'DPI Switch';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-TACT-SW-3MM').hasMatch(elem)) {
        CompName.value = 'Tact Switch (3mm)';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-NUM-KEYPAD').hasMatch(elem)) {
        CompName.value = 'numeric keypads';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-SINGLE-BTN-KEY').hasMatch(elem)) {
        CompName.value = 'single button keypad';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-AUX-M2F-CONN').hasMatch(elem)) {
        CompName.value = 'AUX MALE TO FEMALE CONNECTOR';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-CONN-WHT-BLK').hasMatch(elem)) {
        CompName.value = 'Connector WHITE ND BLACK';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-WTB-CONV-').hasMatch(elem)) {
        CompName.value = 'Wire to Board Converter (Large), (Small)';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-IC-HOLDER').hasMatch(elem)) {
        CompName.value = 'IC HOLDER, FEMALE IC HOLDER';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-PIN-BASE').hasMatch(elem)) {
        CompName.value = '16 pin base, 18 pin base';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'CS-4K79-PINS').hasMatch(elem)) {
        CompName.value = '4K79 pins, 4K75 pins';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'Relay module').hasMatch(elem)) {
        CompName.value = 'Relay module';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'nrf power adapter board').hasMatch(elem)) {
        CompName.value = 'nrf power adapter board';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'GPIO extension board').hasMatch(elem)) {
        CompName.value = 'GPIO extension board';
        Boxname.value = 'CS-01';
      } else if (RegExp(r'OM-SOP16').hasMatch(elem)) {
        CompName.value = 'SOP16';
        Boxname.value = 'CS-01';
      }
    } else if (RegExp(r'^PW').hasMatch(elem)) {
      ClassName.value = 'Power Components';
      print('ClassName set to: ${ClassName.value}');

      // Try to find the component in the database using pattern matching
      final dbComponent = _findPowerComponentBySkuId(elem);
      if (dbComponent != null) {
        CompName.value = dbComponent.name;
        Boxname.value = dbComponent.boxNo;
        Quantity.value = dbComponent.stock;
        print(
            'Found in database: ${dbComponent.name} - Box: ${dbComponent.boxNo} - Stock: ${dbComponent.stock}');
        return;
      }

      // If not found in database, fall back to hardcoded values
      print('Not found in database, using hardcoded values for: $elem');
      if (RegExp(r'PW-VOLT-REG').hasMatch(elem)) {
        CompName.value = 'Voltage regulator (LM7812C)';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-BRIDGE-1A').hasMatch(elem)) {
        CompName.value = '1A Bridge Rectifier';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-PSW-DIP-K').hasMatch(elem)) {
        CompName.value = 'Power Switch Dip k';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-HW221-VOLT-CONV').hasMatch(elem)) {
        CompName.value = 'HW-221 Voltage Converter';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-SOLAR').hasMatch(elem)) {
        CompName.value = 'Solar panel 5V, 6V, 10V';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-BAT12').hasMatch(elem)) {
        CompName.value = 'battery 9v';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-CHR').hasMatch(elem)) {
        CompName.value = 'Charger';
        Boxname.value = 'PW-01';
      } else if (RegExp(r'PW-DRIVER').hasMatch(elem)) {
        CompName.value = 'PWM Motor Driver';
        Boxname.value = 'PW-01';
      } else {
        // If no specific pattern matches, set default values
        CompName.value = 'Unknown Power Component';
        Boxname.value = 'PW-00';
        Quantity.value = 0;
      }
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

  // Method to refresh microcontroller data from database
  Future<void> refreshMicrocontrollerData() async {
    _cacheLoaded = false;
    _microcontrollerCache.clear();
    await _loadMicrocontrollerData();
  }

  // Method to refresh power component data from database
  Future<void> refreshPowerComponentData() async {
    _powerCacheLoaded = false;
    _powercomponentCache.clear();
    await _loadPowerComponentData();
  }

  // Debug method to print cache contents
  void debugPrintCache() {
    print('=== MICROCONTROLLER CACHE DEBUG ===');
    print('Cache loaded: $_cacheLoaded');
    print('Cache size: ${_microcontrollerCache.length}');
    print('Cache contents:');
    for (int i = 0; i < _microcontrollerCache.length; i++) {
      final component = _microcontrollerCache[i];
      print(
          '  [$i] SKU: "${component.skuId}" | Name: "${component.name}" | Stock: ${component.stock}');
    }
    print('=== END MICROCONTROLLER CACHE DEBUG ===');

    print('=== POWER COMPONENT CACHE DEBUG ===');
    print('Power cache loaded: $_powerCacheLoaded');
    print('Power cache size: ${_powercomponentCache.length}');
    print('Power cache contents:');
    for (int i = 0; i < _powercomponentCache.length; i++) {
      final component = _powercomponentCache[i];
      print(
          '  [$i] SKU: "${component.skuId}" | Name: "${component.name}" | Stock: ${component.stock}');
    }
    print('=== END POWER COMPONENT CACHE DEBUG ===');
  }

  // Method to get microcontroller by SKU ID (for external use)
  Component? getMicrocontrollerBySkuId(String skuId) {
    return _findMicrocontrollerBySkuId(skuId);
  }

  // Method to get power component by SKU ID (for external use)
  Component? getPowerComponentBySkuId(String skuId) {
    return _findPowerComponentBySkuId(skuId);
  }

  // Method to get all cached microcontrollers
  List<Component> getAllMicrocontrollers() {
    return List.from(_microcontrollerCache);
  }

  // Method to get all cached power components
  List<Component> getAllPowerComponents() {
    return List.from(_powercomponentCache);
  }

  // Method to check if stock is available
  bool isStockAvailable() {
    return Quantity.value > 0;
  }

  // Test method to verify pattern matching works for both microcontrollers and power components
  Future<void> testPatternMatching() async {
    print('=== TESTING PATTERN MATCHING ===');

    // Ensure caches are loaded
    if (!_cacheLoaded) {
      await _loadMicrocontrollerData();
    }
    if (!_powerCacheLoaded) {
      await _loadPowerComponentData();
    }

    // Test cases for microcontrollers
    final mcTestCases = [
      'MC-ARD-UNO-015', // Should find exact match
      'MC-ARD-UNO-016', // Should find pattern match with 015
      'MC-ARD-UNO-020', // Should find pattern match with 015
      'MC-UNKNOWN-001', // Should not find any match
    ];

    print('\n--- Testing Microcontrollers ---');
    for (final testCase in mcTestCases) {
      print('\n--- Testing: $testCase ---');
      final result = _findMicrocontrollerBySkuId(testCase);
      if (result != null) {
        print(
            '✅ Found: ${result.name} (${result.skuId}) - Stock: ${result.stock}');
      } else {
        print('❌ Not found');
      }
    }

    // Test cases for power components
    final pwTestCases = [
      'PW-VOLT-REG-001', // Should find pattern match
      'PW-SOLAR-005', // Should find pattern match
      'PW-UNKNOWN-001', // Should not find any match
    ];

    print('\n--- Testing Power Components ---');
    for (final testCase in pwTestCases) {
      print('\n--- Testing: $testCase ---');
      final result = _findPowerComponentBySkuId(testCase);
      if (result != null) {
        print(
            '✅ Found: ${result.name} (${result.skuId}) - Stock: ${result.stock}');
      } else {
        print('❌ Not found');
      }
    }

    print('=== END PATTERN MATCHING TEST ===');
  }

  @override
  void onClose() {
    namecontroller.dispose();
    boxnocontroller.dispose();
    super.onClose();
  }
}
