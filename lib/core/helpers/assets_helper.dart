import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/assets_constants.dart';

class AssetsHelper {
  // Image loading with error handling
  static Widget loadImage(
    String assetPath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? 
          Image.asset(
            AssetsConstants.placeholderImage,
            width: width,
            height: height,
            fit: fit,
          );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return frame == null
            ? (placeholder ?? 
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ))
            : child;
      },
    );
  }

  // SVG loading with error handling
  static Widget loadSvg(
    String assetPath, {
    double? width,
    double? height,
    Color? color,
    Widget? errorWidget,
  }) {
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: color != null 
        ? ColorFilter.mode(color, BlendMode.srcIn)
        : null,
      placeholderBuilder: (context) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
      ),
    );
  }

  // Category icon helper
  static Widget getCategoryIcon(String category, {double size = 24}) {
    String iconPath;
    switch (category.toLowerCase()) {
      case 'restaurant':
        iconPath = AssetsConstants.categoryRestaurant;
        break;
      case 'cafe':
        iconPath = AssetsConstants.categoryCafe;
        break;
      case 'shopping':
        iconPath = AssetsConstants.categoryShopping;
        break;
      case 'health':
        iconPath = AssetsConstants.categoryHealth;
        break;
      case 'education':
        iconPath = AssetsConstants.categoryEducation;
        break;
      case 'entertainment':
        iconPath = AssetsConstants.categoryEntertainment;
        break;
      case 'services':
        iconPath = AssetsConstants.categoryServices;
        break;
      case 'gas':
        iconPath = AssetsConstants.categoryGas;
        break;
      default:
        iconPath = AssetsConstants.placeholderImage;
    }
    
    return loadImage(
      iconPath,
      width: size,
      height: size,
    );
  }

  // Navigation icon helper
  static Widget getNavigationIcon(String iconName, {double size = 24, Color? color}) {
    String iconPath;
    switch (iconName.toLowerCase()) {
      case 'home':
        iconPath = AssetsConstants.homeIcon;
        break;
      case 'search':
        iconPath = AssetsConstants.searchIcon;
        break;
      case 'map':
        iconPath = AssetsConstants.mapIcon;
        break;
      case 'profile':
        iconPath = AssetsConstants.profileIcon;
        break;
      case 'notification':
        iconPath = AssetsConstants.notificationIcon;
        break;
      default:
        return Icon(Icons.help_outline, size: size, color: color);
    }
    
    return loadSvg(
      iconPath,
      width: size,
      height: size,
      color: color,
    );
  }

  // Placeholder helpers
  static Widget userPlaceholder({double size = 50}) {
    return loadImage(
      AssetsConstants.placeholderUser,
      width: size,
      height: size,
    );
  }

  static Widget placePlaceholder({double? width, double? height}) {
    return loadImage(
      AssetsConstants.placeholderPlace,
      width: width,
      height: height,
    );
  }

  static Widget noDataPlaceholder({double size = 200}) {
    return loadImage(
      AssetsConstants.noData,
      width: size,
      height: size,
    );
  }

  static Widget noInternetPlaceholder({double size = 200}) {
    return loadImage(
      AssetsConstants.noInternet,
      width: size,
      height: size,
    );
  }
}