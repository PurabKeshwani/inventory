import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/dashboard/classScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassContainer extends StatefulWidget {
  final String label;

  const ClassContainer({super.key, required this.label});

  @override
  State<ClassContainer> createState() => _ClassContainerState();
}

class _ClassContainerState extends State<ClassContainer> {
  final ComponentController componentController = Get.find<ComponentController>();
  final supabase = Supabase.instance.client;
  int totalStock = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTotalStock();
  }

  Future<void> _fetchTotalStock() async {
    // 1. Try reading from pre-warmed CacheController for 0ms instant display
    try {
      final cache = Get.find<CacheController>();
      final cachedList = cache.get<dynamic>(widget.label);
      if (cachedList != null) {
        int sum = 0;
        for (var item in cachedList) {
          if (item is Component) {
            sum += item.stock;
          } else if (item is Map && item['stock'] != null) {
            sum += int.tryParse(item['stock'].toString()) ?? 0;
          }
        }
        if (mounted) {
          setState(() {
            totalStock = sum;
            isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // 2. Fallback to Supabase query
    try {
      final response = await supabase.from(widget.label).select('stock');
      int sum = 0;
      for (var item in response) {
        if (item['stock'] != null) {
          sum += int.tryParse(item['stock'].toString()) ?? 0;
        }
      }
      if (mounted) {
        setState(() {
          totalStock = sum;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          totalStock = 0;
          isLoading = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String label) {
    switch (label) {
      case 'Microcontroller':
        return Icons.memory_rounded;
      case 'Communication Modules':
        return Icons.wifi_tethering_rounded;
      case 'Sensors':
        return Icons.sensors_rounded;
      case 'Displays and Indicators':
        return Icons.tv_rounded;
      case 'Actuators and Motors':
        return Icons.precision_manufacturing_rounded;
      case 'Power Components':
        return Icons.bolt_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String label) {
    switch (label) {
      case 'Microcontroller':
        return const Color(0xff19335A);
      case 'Communication Modules':
        return const Color(0xff007791);
      case 'Sensors':
        return const Color(0xff00897B);
      case 'Displays and Indicators':
        return const Color(0xff5E35B1);
      case 'Actuators and Motors':
        return const Color(0xffD84315);
      case 'Power Components':
        return const Color(0xffE65100);
      default:
        return const Color(0xff455A64);
    }
  }

  String _getCategorySubtitle(String label) {
    switch (label) {
      case 'Microcontroller':
        return 'Arduino, ESP32, STM32, PIC, Raspberry Pi';
      case 'Communication Modules':
        return 'Bluetooth, Wi-Fi, NRF24, LoRa, GSM';
      case 'Sensors':
        return 'Ultrasonic, Temp, IR, Motion, Gas, Pressure';
      case 'Displays and Indicators':
        return 'OLED, LCD, 7-Segment, RGB LEDs, Matrix';
      case 'Actuators and Motors':
        return 'Servo, Stepper, DC Motors, Relays, Drivers';
      case 'Power Components':
        return 'Batteries, Regulators, Step-Down, BMS, Adapters';
      default:
        return 'Tools, Soldering, Breadboards, Cables, Misc';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(widget.label);
    final catIcon = _getCategoryIcon(widget.label);
    final catSubtitle = _getCategorySubtitle(widget.label);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE2EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            componentController.ClassName.value = widget.label;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Classscreen(title: widget.label)),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Category Icon Avatar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                const SizedBox(width: 14),

                // Category Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.montserrat(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff19335A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        catSubtitle,
                        style: GoogleFonts.lato(
                          fontSize: 11.5,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Stock Badge & Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xff19335A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '$totalStock Units',
                              style: GoogleFonts.montserrat(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff19335A),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
