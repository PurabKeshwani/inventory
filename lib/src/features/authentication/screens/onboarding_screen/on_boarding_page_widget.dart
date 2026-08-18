import 'package:flutter/material.dart';
import 'package:inventory/src/constants/image_strings.dart';
import 'package:inventory/src/constants/text_strings.dart';
import 'package:inventory/src/features/authentication/models/model_onboarding.dart';

class onBoardingPageWidget extends StatelessWidget {
  const onBoardingPageWidget({super.key, required this.model});

  final OnBoardingModel model;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: model.bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image(image: AssetImage(model.image)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                model.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                model.counterTitile,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}
