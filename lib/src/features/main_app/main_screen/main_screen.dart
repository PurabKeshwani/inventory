import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/common_widgets/app_bar.dart';
import 'package:inventory/src/common_widgets/bottom_navigation_bar.dart';
import 'package:inventory/src/common_widgets/side_drawer.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/main_app/add_component/add_component_bottom_pop_up.dart';
import 'package:inventory/src/features/main_app/add_component/cons_or%20noncons.dart';
import 'package:inventory/src/features/main_app/dashboard/dashboard_screen.dart';
import 'package:inventory/src/features/main_app/menu_screen/menu_Screen.dart';
import 'package:inventory/src/features/main_app/search_screen/first_screen.dart';
import 'package:inventory/src/features/main_app/search_screen/search_screen.dart';
import 'package:inventory/src/features/main_app/transactions_screen/transaction_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory/src/features/main_app/fines/fines_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final List<Widget> _screenOptions = <Widget>[
    const Dashboard(),
    const SearchScreen(),
    const TransactionScreen(),
    const FinesScreen()
  ];

  @override
  State<MainScreen> createState() => _DashboardState();
}

class _DashboardState extends State<MainScreen> {
  int _selectedIndex = 0;

  final _supabase = Supabase.instance.client;
  final Emailcontroller emailGet = Get.put(Emailcontroller());

  void _onItemTapped(int index) {
    if (index == 2) {
      // Custom action for the middle "Add" button
      ConsOrNonCons(context);
    } else {
      setState(() {
        _selectedIndex = index >= 2 ? index - 1 : index;
      });
    }
  }

  void naamkaran() async {
    try {
      var currentEmail = emailGet.emailget.value.trim();
      if (currentEmail.isEmpty) {
        final sessionUser = _supabase.auth.currentUser;
        if (sessionUser?.email != null) {
          currentEmail = sessionUser!.email!.trim();
          emailGet.emailget.value = currentEmail;
        }
      }
      if (currentEmail.isNotEmpty) {
        final response = await _supabase
            .from('admins')
            .select('name')
            .ilike('emailid', currentEmail);
        if (response.isNotEmpty && response.first['name'] != null) {
          emailGet.Namefrommail.value = response.first['name'].toString();
        } else if (emailGet.Namefrommail.value.isEmpty) {
          emailGet.Namefrommail.value =
              Emailcontroller.formatNameFromEmail(currentEmail);
        }
      }
    } catch (e) {
      debugPrint('Error retrieving admin name in MainScreen: $e');
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    naamkaran();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomSideDrawer(),
      body: Center(
        child: MainScreen._screenOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex >= 2 ? _selectedIndex + 1 : _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
