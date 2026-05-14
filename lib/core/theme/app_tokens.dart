import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets paddingVSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVLg = EdgeInsets.symmetric(vertical: lg);

  static const SizedBox spaceXs = SizedBox(height: xs, width: xs);
  static const SizedBox spaceSm = SizedBox(height: sm, width: sm);
  static const SizedBox spaceMd = SizedBox(height: md, width: md);
  static const SizedBox spaceLg = SizedBox(height: lg, width: lg);
  static const SizedBox spaceXl = SizedBox(height: xl, width: xl);

  static const SizedBox hSpaceXs = SizedBox(width: xs);
  static const SizedBox hSpaceSm = SizedBox(width: sm);
  static const SizedBox hSpaceMd = SizedBox(width: md);
  static const SizedBox hSpaceLg = SizedBox(width: lg);

  static const SizedBox vSpaceXs = SizedBox(height: xs);
  static const SizedBox vSpaceSm = SizedBox(height: sm);
  static const SizedBox vSpaceMd = SizedBox(height: md);
  static const SizedBox vSpaceLg = SizedBox(height: lg);
  static const SizedBox vSpaceXl = SizedBox(height: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double pill = 999.0;

  static BorderRadius borderRadiusSm = BorderRadius.circular(sm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(md);
  static BorderRadius borderRadiusLg = BorderRadius.circular(lg);
  static BorderRadius borderRadiusPill = BorderRadius.circular(pill);

  static RoundedRectangleBorder shapeSm = RoundedRectangleBorder(borderRadius: borderRadiusSm);
  static RoundedRectangleBorder shapeMd = RoundedRectangleBorder(borderRadius: borderRadiusMd);
  static RoundedRectangleBorder shapeLg = RoundedRectangleBorder(borderRadius: borderRadiusLg);
}

class AppIconSize {
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;
}

class AppFontSize {
  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double base = 14.0;
  static const double md = 16.0;
  static const double lg = 18.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double hero = 32.0;
  static const double display = 40.0;
}

class AppAnim {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutQuart;
}