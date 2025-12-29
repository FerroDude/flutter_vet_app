import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// A notification badge widget that displays an unread count.
/// 
/// Used primarily for showing unread message counts on navigation items.
/// The badge automatically hides when count is 0 or less.
class NotificationBadge extends StatelessWidget {
  /// The child widget to wrap with the badge
  final Widget child;
  
  /// The count to display (hidden if <= 0)
  final int count;
  
  /// Optional custom color for the badge
  final Color? badgeColor;
  
  /// Optional custom text color
  final Color? textColor;
  
  /// Position offset from top-right corner
  final double topOffset;
  final double rightOffset;
  
  /// Whether to show as a small dot instead of count
  final bool showDotOnly;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.topOffset = -4,
    this.rightOffset = -4,
    this.showDotOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: topOffset,
          right: rightOffset,
          child: _buildBadge(),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    final bgColor = badgeColor ?? AppTheme.error;
    final fgColor = textColor ?? Colors.white;

    if (showDotOnly) {
      return Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    // Format count (show 99+ for large numbers)
    final displayText = count > 99 ? '99+' : count.toString();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 5.w : 6.w,
        vertical: 2.h,
      ),
      constraints: BoxConstraints(
        minWidth: 18.w,
        minHeight: 18.w,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: fgColor,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// A simple wrapper to add a notification badge to a BottomNavigationBarItem icon
class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final Color? badgeColor;

  const BadgedIcon({
    super.key,
    required this.icon,
    required this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationBadge(
      count: badgeCount,
      badgeColor: badgeColor,
      topOffset: -6,
      rightOffset: -10,
      child: Icon(icon),
    );
  }
}

