import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;
  
  static double sp(BuildContext context, double size) {
    final width = MediaQuery.of(context).size.width;
    return size * (width / 375);
  }
  
  static double hp(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * (percentage / 100);
  }
  
  static double wp(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * (percentage / 100);
  }
  
  static EdgeInsets padding(BuildContext context, {
    double horizontal = 16,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: wp(context, (horizontal / 375) * 100),
      vertical: vertical,
    );
  }
}
