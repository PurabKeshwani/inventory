import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/model.dart';
// import 'package:inventory/src/data/outputComponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/authentication/controllers/selectquerycontroller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComponentInClassScreen extends StatefulWidget {
  final Component component;

  const ComponentInClassScreen({super.key, required this.component});

  @override
  _ComponentInClassScreenState createState() => _ComponentInClassScreenState();
}

class _ComponentInClassScreenState extends State<ComponentInClassScreen> {
  final supabase = Supabase.instance.client;
  final ComponentController componentControl = Get.put(ComponentController());
  final Selectquerycontroller selectquerycontroller =
      Get.put(Selectquerycontroller());
  final TextEditingController warningController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    selectquerycontroller.newres.value.clear();
    selectquerycontroller.fetchComponents(widget.component.name);
  }
  
  Future<void> _refreshData() async {
    selectquerycontroller.newres.value.clear();
    selectquerycontroller.fetchComponents(widget.component.name);
  }

  //need a setstate to display the item

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 154, 210, 255),
            Color.fromARGB(255, 213, 245, 252),
            Color.fromARGB(255, 242, 254, 255)
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.component.name,
            style: const TextStyle(color: Colors.black),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height,
              ),
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 154, 210, 255),
                    Color.fromARGB(255, 213, 245, 252),
                    Color.fromARGB(255, 242, 254, 255)
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30, left: 40),
                    child: Text(
                      widget.component.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 35,
                            decoration: const BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "SkuId",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Box No",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Stock",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Warning",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Obx(
                              () => ListView.builder(
                                itemCount: selectquerycontroller.newres.length,
                                itemBuilder: (ctx, index) {
                                  final listcomponent =
                                      selectquerycontroller.newres[index];

                                  return GestureDetector(
                                    onLongPress: () =>
                                        _showEditWarningDialog(listcomponent),
                                    child: Container(
                                      height: 35,
                                      decoration: const BoxDecoration(
                                        border: Border.symmetric(
                                          horizontal:
                                              BorderSide(color: Colors.black),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              listcomponent.skuid.toString(),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.lato(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              listcomponent.boxNo.toString(),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.lato(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              listcomponent.stock.toString(),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.lato(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child:
                                                  listcomponent.warning
                                                          .toString()
                                                          .isNotEmpty
                                                      ? GestureDetector(
                                                          onTap: () => {
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      Dialog(
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              16),
                                                                ),
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                              20),
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Container(
                                                                        padding:
                                                                            const EdgeInsets.all(12),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .red
                                                                              .withValues(alpha: 0.1),
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                        child:
                                                                            const Icon(
                                                                          Icons
                                                                              .warning_amber_rounded,
                                                                          color:
                                                                              Colors.red,
                                                                          size:
                                                                              40,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              16),
                                                                      const Text(
                                                                        'Warning',
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Colors.red,
                                                                          fontSize:
                                                                              24,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              12),
                                                                      Text(
                                                                        listcomponent
                                                                            .warning
                                                                            .toString(),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          height:
                                                                              1.5,
                                                                          color: Colors
                                                                              .red
                                                                              .shade700,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              20),
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.pop(context),
                                                                        child:
                                                                            const Text(
                                                                          'OK',
                                                                          style:
                                                                              TextStyle(
                                                                            color:
                                                                                Colors.black,
                                                                            fontSize:
                                                                                16,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          },
                                                          child: const Icon(
                                                              Icons
                                                                  .warning_amber_rounded,
                                                              color: Colors.red,
                                                              size: 20),
                                                        )
                                                      : const SizedBox(width: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditWarningDialog(dynamic component) {
    warningController.text = component.warning?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Warning',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: warningController,
                decoration: const InputDecoration(
                  labelText: 'Warning Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        // Print debug information
                        print('Updating warning for:');
                        print('Table: ${componentControl.ClassName.value}');
                        print('SKUID: ${component.skuid}');
                        print('New warning: ${warningController.text}');

                        // Update the warning in the database
                        final response = await supabase
                            .from(componentControl.ClassName.value)
                            .update({'warning': warningController.text}).eq(
                                'skuid', component.skuid);

                        print('Update response: $response');
                        _refreshData();
                        Navigator.pop(context);
                      } catch (e) {
                        print('Error updating warning: $e');
                        // Optionally show error to user
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to update warning: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
