import 'package:get/get.dart';
import 'package:inventory/src/data/outputComponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Selectquerycontroller extends GetxController {
  final supabase = Supabase.instance.client;
  final ComponentController componentControl = Get.find<ComponentController>();
  RxList<Outputcomponent> newres = <Outputcomponent>[].obs;

  void fetchComponents(compname) async {
    print(componentControl.ClassName.value);

    final response = await supabase
        .from(componentControl.ClassName.value)
        .select()
        .eq('name', compname);

    for (var entry in response) {
      final Outputcomponent com = Outputcomponent(
          skuid: entry['skuid'],
          boxNo: entry['boxno'],
          stock: entry['stock'],
          warning: entry['warning']);
      newres.add(com);
    }
  }
}
