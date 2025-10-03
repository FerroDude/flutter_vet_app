import 'package:flutter/material.dart';

class ListPlaceholder extends StatelessWidget {
  const ListPlaceholder({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 64,
    this.iconColor,
    this.textStyle,
  });

  final IconData icon;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor ?? Colors.grey),
            const SizedBox(height: 16),
            Text(
              text,
              style: textStyle ?? const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
