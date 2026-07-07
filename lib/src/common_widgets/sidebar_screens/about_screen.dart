import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About',
          style: GoogleFonts.montserrat(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xffC5E3FF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'International Society of Automation (ISA)',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The International Society of Automation (ISA) is a leading global organization dedicated to the advancement of automation and control technology. ISA aims to support automation professionals through educational programs, certification, and networking opportunities. With a focus on innovation and excellence, ISA helps shape the future of industrial automation and control systems by fostering collaboration and sharing best practices across the industry.',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ISA-VESIT',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ISA-VESIT is the student chapter of ISA at Vivekanand Education Society Institute of Technology (VESIT). As an extension of ISA, our chapter is devoted to bridging the gap between academic knowledge and industry practice in automation. We offer students various opportunities to engage in hands-on learning through workshops, seminars, and projects that enhance their understanding of automation technologies. Our mission is to prepare students for successful careers in automation by providing them with practical skills and insights into industry trends.',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'The Inventorium App',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The Inventorium App is an advanced application developed by ISA-VESIT to streamline the management of automation components and resources. The app is designed to meet the needs of both educational and professional environments with features that include:',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '• Efficient Inventory Management: Manage and track automation components with ease, ensuring accurate organization and availability of resources.\n'
                '• Real-time Data Access: Access up-to-date information on inventory items, including their status, location, and usage history.\n'
                '• User-friendly Interface: Enjoy an intuitive and responsive design that facilitates smooth navigation and effective management.\n'
                '• Advanced Search and Filter Options: Quickly find specific items using powerful search and filter capabilities, enhancing resource management.',
                style: GoogleFonts.montserrat(
                  color: const Color.fromARGB(255, 229, 228, 228),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
