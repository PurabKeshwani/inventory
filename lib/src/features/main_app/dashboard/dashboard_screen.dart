import 'package:flutter/material.dart';
import 'package:inventory/src/features/main_app/dashboard/classes_widget.dart';
import 'package:inventory/src/features/main_app/symposium/symposium_scanner_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "symposiumBtn",
        backgroundColor: const Color(0xff19335A),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SymposiumScannerScreen()));
        },
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      body: const SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClassContainer(label: "Microcontroller"),
            ClassContainer(label: "Communication Modules"),
            ClassContainer(label: "Sensors"),
            ClassContainer(label: "Displays and Indicators"),
            ClassContainer(label: "Actuators and Motors"),
            ClassContainer(label: "Power Components"),
            ClassContainer(label: "Others")
          ],
        ),
      ),
    );
  }
}
