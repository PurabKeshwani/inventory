import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/dashboard/classScreen.dart';
import 'package:inventory/src/features/main_app/search_screen/search_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassContainer extends StatefulWidget {
  final String label;

  const ClassContainer({super.key, required this.label});

  @override
  State<ClassContainer> createState() => _ClassContainerState();
}

class _ClassContainerState extends State<ClassContainer> {
  final ComponentController componentController =
      Get.put(ComponentController());
  final supabase = Supabase.instance.client;
  int totalStock = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTotalStock();
  }

  Future<void> _fetchTotalStock() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get the table name based on the class label
      String tableName = widget.label;

      // Fetch all components from the specific table and sum their stock
      final response = await supabase.from(tableName).select('stock');

      if (response is List) {
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
      } else {
        if (mounted) {
          setState(() {
            totalStock = 0;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching stock for ${widget.label}: $e');
      if (mounted) {
        setState(() {
          totalStock = 0;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        componentController.ClassName.value = widget.label;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => Classscreen(title: widget.label)));
      },
      splashColor: const Color.fromARGB(255, 211, 220, 242),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color.fromARGB(109, 214, 244, 255)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    totalStock.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  )
          ],
        ),
      ),
    );
  }
}
