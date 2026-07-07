import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/main_app/main_screen/main_screen.dart';

class Emailcontroller extends GetxController {
  RxString emailget = ''.obs;
  RxBool isValidating = false.obs;
  RxString Namefrommail = ''.obs;

  final List<String> emails = [
    'n.gopalkrishnan@ves.ac.in',
    '2024.tanvi.jagade@ves.ac.in',
    '2024.dhruv.sangam@ves.ac.in',
    '2024.varun.santani@ves.ac.in',
    '2024.nirmiti.nalawade@ves.ac.in',
    'd2025.aditya.sasane@ves.ac.in',
    '2024.sana.patil@ves.ac.in',
    '2024.arnav.nair@ves.ac.in',
    'adityamhatre2003@gmail.com',
    'sahoocharchit@gmail.com',
    '2022.kaustubh.natalkar@ves.ac.in',
    'd2021.atishkar.singh@ves.ac.in',
    'kaustubhworlikar1308@gmail.com',
    'd2021.rashid.sarang@ves.ac.in',
    '2022.gautam.singh@ves.ac.in',
    'd2023.aniket.pandhari@ves.ac.in',
    'Sinhaaakarsh0@gmail.com',
    '2023.ronit.chugwani@ves.ac.in',
    '2023.paayal.kapoor@ves.ac.in',
    '2023.nidhi.bamhane@ves.ac.in',
    '2023.krishnan.h@ves.ac.in',
    '2023.akshay.nambiar@ves.ac.in'
  ];

  final Map<String, String> emailToName = {
    'n.gopalkrishnan@ves.ac.in': 'N. Gopalkrishnan',
    '2024.tanvi.jagade@ves.ac.in': 'Tanvi Jagade',
    '2024.dhruv.sangam@ves.ac.in': 'Dhruv Sangam',
    '2024.varun.santani@ves.ac.in': 'Varun Santani',
    '2024.nirmiti.nalawade@ves.ac.in': 'Nirmiti Nalawade',
    'd2025.aditya.sasane@ves.ac.in': 'Aditya Sasane',
    '2024.sana.patil@ves.ac.in': 'Sana Patil',
    '2024.arnav.nair@ves.ac.in': 'Arnav Nair',
    'adityamhatre2003@gmail.com': 'Aditya Mhatre',
    'sahoocharchit@gmail.com': 'Charchit Sahoo',
    '2022.kaustubh.natalkar@ves.ac.in': 'Kaustubh Natalkar',
    'd2021.atishkar.singh@ves.ac.in': 'Atishkar Singh',
    'kaustubhworlikar1308@gmail.com': 'Kaustubh Worlikar',
    'd2021.rashid.sarang@ves.ac.in': 'Rashid Sarang',
    '2022.gautam.singh@ves.ac.in': 'Gautam Singh',
    'd2023.aniket.pandhari@ves.ac.in': 'Aniket Pandhari',
    'Sinhaaakarsh0@gmail.com': 'Aakarsh SInha',
    '2023.ronit.chugwani@ves.ac.in': 'Ronit Chugwani',
    '2023.paayal.kapoor@ves.ac.in': 'Paayal Kapoor',
    '2023.nidhi.bamhane@ves.ac.in': 'Nidhi Bamhane',
    '2023.krishnan.h@ves.ac.in': 'Krishnan H',
    '2023.akshay.nambiar@ves.ac.in': 'Akshay Nambiar'
  };

  void mailchecker() {
    if (emails.contains(emailget.value)) {
      print('email is valid');
      isValidating.value = true;
      Get.to(const MainScreen());
    } else {
      isValidating.value = false;
    }
  }
}
