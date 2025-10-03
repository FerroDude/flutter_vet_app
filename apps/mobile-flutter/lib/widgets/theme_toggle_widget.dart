import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_manager.dart';

/// A beautiful theme toggle widget that allows users to switch between light/dark/system modes
class ThemeToggleWidget extends StatelessWidget {
  final bool showLabel;
  final bool isExpanded;

  const ThemeToggleWidget({
    super.key,
    this.showLabel = true,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return isExpanded
            ? _buildExpandedToggle(context, themeManager)
            : _buildCompactToggle(context, themeManager);
      },
    );
  }

  Widget _buildCompactToggle(BuildContext context, ThemeManager themeManager) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            context,
            themeManager,
            ThemeMode.light,
            Icons.wb_sunny_outlined,
            Icons.wb_sunny,
          ),
          _buildToggleButton(
            context,
            themeManager,
            ThemeMode.system,
            Icons.settings_outlined,
            Icons.settings,
          ),
          _buildToggleButton(
            context,
            themeManager,
            ThemeMode.dark,
            Icons.nightlight_outlined,
            Icons.nightlight,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedToggle(BuildContext context, ThemeManager themeManager) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing3),
              child: Text(
                'Theme',
                style: AppTheme.labelLarge.copyWith(color: context.textColor),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _buildExpandedButton(
                  context,
                  themeManager,
                  ThemeMode.light,
                  Icons.wb_sunny,
                  'Light',
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildExpandedButton(
                  context,
                  themeManager,
                  ThemeMode.system,
                  Icons.settings,
                  'System',
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildExpandedButton(
                  context,
                  themeManager,
                  ThemeMode.dark,
                  Icons.nightlight,
                  'Dark',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context,
    ThemeManager themeManager,
    ThemeMode mode,
    IconData outlineIcon,
    IconData filledIcon,
  ) {
    final isSelected = themeManager.themeMode == mode;

    return GestureDetector(
      onTap: () => themeManager.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spacing3),
        margin: const EdgeInsets.all(AppTheme.spacing1),
        decoration: BoxDecoration(
          color: isSelected ? context.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Icon(
          isSelected ? filledIcon : outlineIcon,
          size: 20,
          color: isSelected
              ? (context.isDarkMode
                    ? AppTheme.darkBackgroundPrimary
                    : Colors.white)
              : context.textColor,
        ),
      ),
    );
  }

  Widget _buildExpandedButton(
    BuildContext context,
    ThemeManager themeManager,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = themeManager.themeMode == mode;

    return GestureDetector(
      onTap: () => themeManager.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacing3,
          horizontal: AppTheme.spacing2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? context.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isSelected ? null : Border.all(color: context.borderMedium),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? (context.isDarkMode
                        ? AppTheme.darkBackgroundPrimary
                        : Colors.white)
                  : context.textColor,
            ),
            const SizedBox(height: AppTheme.spacing1),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected
                    ? (context.isDarkMode
                          ? AppTheme.darkBackgroundPrimary
                          : Colors.white)
                    : context.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple theme toggle switch for use in app bars or settings
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return IconButton(
          onPressed: () {
            // Cycle through: Light -> Dark -> System -> Light
            switch (themeManager.themeMode) {
              case ThemeMode.light:
                themeManager.setThemeMode(ThemeMode.dark);
                break;
              case ThemeMode.dark:
                themeManager.setThemeMode(ThemeMode.system);
                break;
              case ThemeMode.system:
                themeManager.setThemeMode(ThemeMode.light);
                break;
            }
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _getThemeIcon(themeManager.themeMode, context.isDarkMode),
              key: ValueKey(themeManager.themeMode),
              color: context.isDarkMode ? Colors.white : context.textColor,
            ),
          ),
          tooltip:
              'Switch to ${_getNextThemeLabel(themeManager.themeMode)} theme',
        );
      },
    );
  }

  IconData _getThemeIcon(ThemeMode mode, bool isDarkMode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.wb_sunny;
      case ThemeMode.dark:
        return Icons.nightlight;
      case ThemeMode.system:
        return isDarkMode ? Icons.nightlight : Icons.wb_sunny;
    }
  }

  String _getNextThemeLabel(ThemeMode current) {
    switch (current) {
      case ThemeMode.light:
        return 'dark';
      case ThemeMode.dark:
        return 'system';
      case ThemeMode.system:
        return 'light';
    }
  }
}
