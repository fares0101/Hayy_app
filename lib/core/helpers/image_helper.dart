import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageHelper {
  // Pre-built containers for onboarding images to avoid loading delays
  static Widget getOnboardingImage(int index) {
    switch (index) {
      case 0:
        return Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.location_on_rounded,
            size: 120,
            color: Colors.blue.shade400,
          ),
        );
      case 1:
        return Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.star_rounded,
            size: 120,
            color: Colors.green.shade400,
          ),
        );
      case 2:
        return Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.people_rounded,
            size: 120,
            color: Colors.orange.shade400,
          ),
        );
      default:
        return Container(
          height: 300,
          color: Colors.grey.shade200,
        );
    }
  }

  static Widget buildFastSvg(String assetPath) {
    return SvgPicture.asset(
      assetPath,
      height: 300,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Container(
        height: 300,
        color: Colors.transparent,
      ),
    );
  }
}