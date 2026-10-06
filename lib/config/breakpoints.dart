import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double tv = 1600;
}

enum ScreenType { mobile, tablet, desktop, tv }

class ScreenConfig {
  static ScreenType of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.tv) return ScreenType.tv;
    if (width >= Breakpoints.desktop) return ScreenType.desktop;
    if (width >= Breakpoints.tablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static int gridColumns(BuildContext context) {
    switch (of(context)) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 3;
      case ScreenType.desktop:
        return 4;
      case ScreenType.tv:
        return 6;
    }
  }

  static double horizontalPadding(BuildContext context) {
    switch (of(context)) {
      case ScreenType.mobile:
        return 12;
      case ScreenType.tablet:
        return 24;
      case ScreenType.desktop:
        return 40;
      case ScreenType.tv:
        return 64;
    }
  }

  static double cardHeight(BuildContext context) {
    switch (of(context)) {
      case ScreenType.mobile:
        return 180;
      case ScreenType.tablet:
        return 220;
      case ScreenType.desktop:
        return 260;
      case ScreenType.tv:
        return 300;
    }
  }

  static bool isTV(BuildContext context) => of(context) == ScreenType.tv;
}
