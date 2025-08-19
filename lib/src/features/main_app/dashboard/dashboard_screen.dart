import 'package:flutter/material.dart';
import 'package:inventory/src/features/main_app/dashboard/classes_widget.dart';
import 'package:inventory/src/features/main_app/dashboard/workshop_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 0 && !_showFab) {
      setState(() {
        _showFab = true;
      });
    } else if (_scrollController.position.pixels == 0 && _showFab) {
      setState(() {
        _showFab = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _showFab ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showFab ? 1.0 : 0.0,
          child: FloatingActionButton(
            backgroundColor: Colors.lightBlue[100],
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => WorkshopPage()));
            },
            child: const Icon(Icons.change_circle_outlined),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: const Column(
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
