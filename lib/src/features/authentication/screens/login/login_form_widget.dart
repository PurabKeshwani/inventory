import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final supabase = Supabase.instance.client;

  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();

  final Emailcontroller emailGet = Get.put(Emailcontroller());

  bool isTermsAccepted = false; // Track the state of the checkbox

  Future<void> emailsignin() async {
    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept the terms and conditions to proceed.")),
      );
      return;
    }

    final response = await supabase.auth.signInWithPassword(
        password: passwordcontroller.text, email: emailcontroller.text);

    try {
      if (response.user != null) {
        emailGet.emailget.value = emailcontroller.text;
        emailGet.mailchecker();
        emailcontroller.clear();
        passwordcontroller.clear();
        final session = response.session;
        await supabase.auth.setSession(session as String);
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('email', emailGet.emailget.value);
      }
    } on Exception {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("You are not an ISA Member!")));
    }
  }

  @override
  void initState() {
    super.initState();

    supabase.auth.refreshSession().then((session) {
      emailGet.emailget.value = session.user!.email!;
      emailGet.mailchecker();
    });
  }

  TextStyle termsTextStyle = const TextStyle(
    fontSize: 16.0,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: emailcontroller,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_outlined),
                  labelText: "Email",
                  hintText: "Email",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(
              height: 10,
            ),
            TextFormField(
              controller: passwordcontroller,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.fingerprint),
                  labelText: "Password",
                  hintText: "Password",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: isTermsAccepted,
                  onChanged: (bool? value) {
                    setState(() {
                      isTermsAccepted = value ?? false;
                    });
                  },
                ),
                const Text('I agree to the'),
                TextButton(
                  onPressed: () {
                    _showTermsAndConditions();
                  },
                  child: const Text("Terms and Conditions"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () {
                    showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Select One Option",
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: const Color.fromARGB(
                                              110, 180, 170, 132)),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.mail_outline_rounded,
                                            size: 40,
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Email",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium,
                                              ),
                                              const Text("Verify using Email")
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ));
                  },
                  child: const Text("Forgot Password")),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.email),
                onPressed: () {
                  emailsignin();
                },
                label: const Text("Log-In with Email"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsAndConditions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Terms and Conditions",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '1. Objective\n'
                'The purpose of these guidelines is to provide a clear understanding of the rules and procedures for the ISA-VESIT inventory system.\n\n'
                '2. Issuance of Components\n'
                '● Eligibility: Only students who are currently enrolled for ISA Memberships are eligible to borrow components.\n'
                '● Issuance Procedure:\n'
                '  ○ Components will be issued based on availability and necessity.\n'
                '  ○ A record of issued components will be maintained by the ISA Council.\n\n'
                '3. Student Responsibilities\n'
                '● Care: Students are responsible for the proper care and handling of the components.\n'
                '● Usage: Components must be used only for their intended educational or project purposes.\n'
                '● Return: Components must be returned by the due date specified at the time of issuance.\n'
                '● Modification: Modification of the components is not allowed.\n'
                '● Damage: No damage is allowed. Students will have to pay the entire amount if the component is damaged.\n'
                '● Loss: If a component is lost, the student is responsible for it and has to pay the entire amount of the component as listed below.\n'
                '● Issuance/Reissuance: Components must be issued or reissued in the presence of and with the approval of a council member only.\n'
                '● Reissue: The component should be reissued within 1 month of time after issuing the component.\n'
                '● Timing: For issuance/reissuance of the component the timings are 1) 1:00 pm - 1:30 pm 2) 3:30 pm - 4:00 pm\n\n'
                '4. Return Policy\n'
                '● Due Date: Components must be returned by the due date specified during issuance.\n'
                '● Condition: Components must be returned in the same condition as they were issued.\n'
                '● All the components should be returned to the council before the end semester exam.\n'
                '● Refer Fine Structure for more terms and conditions regarding the fine payment.\n\n'
                '5. Fine Structure and Payment\n'
                '● Late Returns:\n'
                '  ○ A fine will be imposed for each day the component is returned late.\n'
                '  ○ The maximum late fine will not exceed 2500 Rs.\n'
                '● Component Damage:\n'
                '  ○ No damage to the components would be accepted.\n'
                '  ○ In case of damage: Replacement Cost of the new component.\n'
                '● Loss of Component:\n'
                '  ○ Full replacement cost of the component will be charged.\n'
                '● Payment:\n'
                '  ○ Fines must be paid within 5 days of notification.\n'
                '  ○ Payment should be made online.\n\n'
                '6. Consequences of Non-Payment\n'
                '● Failure to pay fines may result in:\n'
                '  ○ Suspension of borrowing privileges.\n'
                '  ○ Membership Suspension.\n'
                '  ○ Clearance for collecting Leaving Certificate would not be provided by the Central Library of College.\n\n'
                '7. Dispute Resolution\n'
                '● Students who wish to dispute a fine may do so by submitting a written appeal to the ISA committee within 3 days of fine notification.\n'
                '● The decision of the ISA committee will be final.\n\n'
                '8. Policy Review\n'
                '● This policy will be reviewed annually and is subject to change. Updates will be communicated to all students via email and WhatsApp.\n\n'
                '9. Component Price List:\n'
                'https://bit.ly/ComponentPrice\n'
                'Note: Subject to Change of Price\n\n'
                '10. Contact Information\n'
                'For any questions or concerns regarding this policy, please contact:\n'
                'Sr. Treasurer: Atishkar Singh\n'
                'Phone No: 9049120954',
                style: termsTextStyle.copyWith(color: Colors.white), // Set color to white
              ),
            ],
          ),
        ),
      ),
    );
  }
}
