import 'package:flutter/material.dart';
import 'package:inventory/src/features/main_app/add_component/NewEntry_consumable.dart';
import 'package:inventory/src/features/main_app/add_component/NewEntry_nonConsumable.dart';

Future<dynamic> AddCompBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    sheetAnimationStyle:
        const AnimationStyle(curve: Curves.bounceInOut, duration: Durations.long4),
    context: context,
    useSafeArea: true,
    constraints: const BoxConstraints.expand(),
    isScrollControlled: true,
    elevation: 10,
    backgroundColor: const Color(0xffC5E3FF),
    builder: (BuildContext context) => const Newentry(),
  );
}

Future<dynamic> AddConsumableSheet(BuildContext context) {
  return showModalBottomSheet(
    sheetAnimationStyle:
        const AnimationStyle(curve: Curves.bounceInOut, duration: Durations.long4),
    context: context,
    useSafeArea: true,
    constraints: const BoxConstraints.expand(),
    isScrollControlled: true,
    elevation: 10,
    backgroundColor: const Color(0xffC5E3FF),
    builder: (BuildContext context) => const NewConsumableentry(),
  );
}
