import 'package:get/get.dart';
import 'package:inventory/src/features/authentication/models/model_onboarding.dart';
import 'package:inventory/src/features/authentication/screens/onboarding_screen/on_boarding_page_widget.dart';
import 'package:liquid_swipe/PageHelpers/LiquidController.dart';

import '../../../constants/colors.dart';
import '../../../constants/image_strings.dart';
import '../../../constants/text_strings.dart';

class OnBoardingController extends GetxController {
  final controller = LiquidController();

  RxInt currentPage = 0.obs;

  final pages = [
    onBoardingPageWidget(
        model: OnBoardingModel(
            image: onBoardImage1,
            title: onBoardText1,
            bgColor: onboardcolor2,
            counterTitile: counterTitle1)),
    onBoardingPageWidget(
        model: OnBoardingModel(
            image: onBoardImage1,
            title: onBoardText2,
            counterTitile: counterTitle2,
            bgColor: onboardcolor1)),
    onBoardingPageWidget(
        model: OnBoardingModel(
            image: onBoardImage1,
            title: onBoardText3,
            counterTitile: counterTitle3,
            bgColor: onboardcolor3))
  ];

  onPageChangedCallback(int activePageIndex) {
    currentPage.value = activePageIndex;
  }

  skip() => controller.jumpToPage(page: 2);
  animateToNextSlide() {
    int nextPage = controller.currentPage + 1;
    controller.animateToPage(page: nextPage);
  }
}
