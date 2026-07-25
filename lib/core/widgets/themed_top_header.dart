import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Drop-in replacement for the old ThemedTopHeader.
/// Now delegates to OrangeGradientHeader for a modern look.
class ThemedTopHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailing;

  const ThemedTopHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.trailing,
  });

  static double heightFor(BuildContext context) =>
      OrangeGradientHeader.heightFor(context);

  @override
  Widget build(BuildContext context) {
    return OrangeGradientHeader(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      trailing: trailing,
    );
  }
}
