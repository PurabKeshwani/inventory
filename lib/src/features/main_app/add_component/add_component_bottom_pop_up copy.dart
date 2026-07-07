import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/add_component/NewEntry_consumable.dart';
// import 'package:inventory/src/features/main_app/add_component/NewEntry.dart';
// import 'package:inventory/src/features/authentication/screens/scanner_screen/scanner_screen.dart';

Future<dynamic> AddConsumableSheet(BuildContext context) {
  final componentcontroller = Get.put(ComponentController(), permanent: true);
  componentcontroller.reset();
  return showModalBottomSheet(
    sheetAnimationStyle:
        const AnimationStyle(curve: Curves.bounceInOut, duration: Durations.long4),
    context: context,
    useSafeArea: true,
    constraints: const BoxConstraints.expand(),
    isScrollControlled: true,
    elevation: 10,
    backgroundColor: const Color(0xffC5E3FF),
    builder: (BuildContext context) => WillPopScope(
      onWillPop: () async {
        Get.delete<ComponentController>();
        return true;
      },
      child: const NewConsumableentry(),
    ),
  );
}
