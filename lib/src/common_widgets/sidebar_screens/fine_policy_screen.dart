import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FinePolicyPdf extends StatelessWidget {
  const FinePolicyPdf({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fine Policy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rules and Regulations for Inventory of ISA-VESIT',
                style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '1. Objective\n'
                'The purpose of this policy is to outline the responsibilities of students when borrowing components from the ISA and to establish a system of fines for late returns, damage, or loss of components.\n\n'
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
                '● Loss: If a component is lost, the student is responsible for it and has to pay the entire amount of the component as listed below [refer 9].\n'
                '● Issuance/Reissuance: Components must be issued or reissued in the presence of and with the approval of a council member only.\n'
                '● Reissue: The component should be reissued within 1 month of time after issuing the component.\n'
                '● Timing: For issuance/reissuance of the component the timings are 1) 1:00 pm - 1:30 pm 2) 3:30 pm - 4:00 pm\n\n'
                '4. Return policy\n'
                '● Due Date: Components must be returned by the due date specified during issuance.\n'
                '● Condition: Components must be returned in the same condition as they were issued.\n'
                '● All the components should be returned to the council before the end semester exam.\n'
                '● Refer Fine Structure [5] for more terms and conditions regarding the fine payment.\n\n'
                '5. Fine structure and payment\n'
                'Sr. no | Amount | Fine | Example\n'
                '1 | 0 to 99 | 10 Rs | If your component is worth 50 Rs then 10 Rs fine is applied.\n'
                '2 | 100 to 499 | 12% | If your component is worth 200 Rs then 12% fine is applied i.e = 24rs.\n'
                '3 | 500 to 999 | 18% | If your component is worth 800 Rs then 18% fine is applied i.e = 144rs.\n'
                '4 | 1000 plus | 28% | If your component is worth 1000 Rs then 28% fine is applied i.e = 280rs.\n\n'
                '● Late Returns:\n'
                '  ○ A fine of [refer 5] per day will be imposed for each day the component is returned late.\n'
                '  ○ The maximum late fine will not exceed 2500 Rs.\n'
                '● Component Damage:\n'
                '  ○ No damage to the components would be accepted.\n'
                '  ○ In case of damage: Replacement Cost of the new component [refer 9].\n'
                '● Loss of component:\n'
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
                '9. Component price list:\n'
                'https://bit.ly/ComponentPrice\n'
                'https://bit.ly/ComponentPrice\n'
                'Note: Subject to Change of Price\n\n'
                '10. Contact Information\n'
                'For any questions or concerns regarding this policy, please contact:\n'
                'Sr. Treasurer: Atishkar Singh\n'
                'Phone No: 9049120954',
                style: GoogleFonts.lato(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
