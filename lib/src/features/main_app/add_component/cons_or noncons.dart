import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/authentication/screens/scanner_screen/scanner_screen.dart';
import 'package:inventory/src/features/main_app/add_component/chooseOption.dart';

Future<dynamic> ConsOrNonCons(BuildContext context) {
  return showModalBottomSheet(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(60), // Adjust the radius as needed
      ),
    ),
    sheetAnimationStyle:
        const AnimationStyle(curve: Curves.bounceInOut, duration: Durations.long4),
    context: context,
    useSafeArea: true,
    constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.25,
        maxWidth: MediaQuery.of(context).size.width * 1),
    isScrollControlled: true,
    elevation: 10,
    backgroundColor: const Color.fromARGB(255, 172, 209, 242),
    builder: (BuildContext context) => Chooseoption(),
  );
}
