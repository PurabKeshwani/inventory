import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventory/firebase_options.dart';
import 'package:get/get.dart';
import 'package:inventory/src/constants/image_strings.dart';
import 'package:inventory/src/features/authentication/screens/login/login_form_widget.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image(
                  image: const AssetImage(
                      "assets/images/isa-vesit-color-logo.png"),
                  height: size.height * 0.2,
                ),
                const SizedBox(
                  height: 15,
                ),
                Text("Welcome Back",
                    style: Theme.of(context).textTheme.headlineMedium),
                const LoginForm(),
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.center,
                //   children: [
                //     const Text("OR"),
                //     SizedBox(
                //       width: double.infinity,
                //       child: OutlinedButton.icon(
                //         icon: const Image(
                //           image: AssetImage(GoogleLogo),
                //           width: 20,
                //         ),
                //         onPressed: () {},
                //         label: const Text("Sign-In with Google"),
                //       ),
                //     ),
                //     const SizedBox(
                //       height: 10,
                //     ),
                //     TextButton(
                //         onPressed: () {},
                //         child: const Text("Already have an account"))
                //   ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
