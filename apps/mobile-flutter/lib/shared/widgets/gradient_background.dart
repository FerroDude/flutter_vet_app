import 'package:flutter/material.dart';

/// Reusable gradient background widget
/// Creates a clean, professional background
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors:
              colors ??
              [
                const Color(0xFFF0F0F0), // Light grey at top
                Colors.white, // White at bottom
              ],
        ),
      ),
      child: child,
    );
  }
}
