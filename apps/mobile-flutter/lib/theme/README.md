# VetPlus Design System

This design system provides a consistent visual language for both the Flutter mobile app and React web application.

## Files Structure

- `app_theme.dart` - Flutter theme implementation
- `design_tokens.json` - Platform-agnostic design tokens for React/Web
- `README.md` - This documentation

## Design Philosophy

The app uses a **dark gradient background with white cards** aesthetic:

- Dark navy gradient flows from top to bottom
- Content is displayed in elevated white cards with shadows
- High contrast between background and content for readability

## Color Palette

### Primary Colors (Navy Scale)

| Name     | Hex       | Usage                              |
| -------- | --------- | ---------------------------------- |
| Navy 500 | `#1B2A41` | Primary brand color, text in cards |
| Navy 600 | `#152233` | Darker hover states                |
| Navy 700 | `#0C1821` | Secondary text, icons              |
| Navy 400 | `#324A5F` | Accents, medium emphasis           |

### Brand Colors

| Name             | Hex       | Usage                             |
| ---------------- | --------- | --------------------------------- |
| Brand Blue       | `#1172B0` | Links, primary actions            |
| Brand Blue Light | `#64B5F6` | Appointment indicators            |
| Brand Teal       | `#57B4A4` | Medication indicators             |
| Brand Mint       | `#85E7A9` | Success states, positive feedback |

### Gradient Colors

The background gradient uses four color stops for subtle transitions:

```
Start:  #1B2A41 (0%)
Mid 1:  #1E3147 (30%)
Mid 2:  #21374D (60%)
End:    #243D53 (100%)
```

### Semantic Colors

| Name    | Hex       | Usage                             |
| ------- | --------- | --------------------------------- |
| Success | `#10B981` | Success messages, positive states |
| Warning | `#F59E0B` | Warnings, symptom indicators      |
| Error   | `#EF4444` | Errors, destructive actions       |
| Info    | `#3B82F6` | Informational messages            |

### Neutral Colors

| Name        | Hex       | Usage                               |
| ----------- | --------- | ----------------------------------- |
| Neutral 50  | `#FFFFFF` | Card backgrounds, input backgrounds |
| Neutral 100 | `#F8F9FA` | Secondary surfaces                  |
| Neutral 200 | `#CCC9DC` | Light borders, dividers             |
| Neutral 300 | `#A8A5B8` | Medium borders                      |

## Typography

- **Font Family**: Inter (via Google Fonts)
- **Scale**: 10px to 32px
- **Weights**: Regular (400), Medium (500), Semi-bold (600), Bold (700)

### Text Colors

| Context                 | Color    | Opacity |
| ----------------------- | -------- | ------- |
| On gradient (primary)   | White    | 100%    |
| On gradient (secondary) | White    | 70%     |
| In cards (primary)      | Navy 500 | 100%    |
| In cards (secondary)    | Navy 700 | 100%    |

## Spacing

Based on 4px grid system (responsive with ScreenUtil):

| Token     | Value | Usage                  |
| --------- | ----- | ---------------------- |
| spacing1  | 4px   | Minimal gaps           |
| spacing2  | 8px   | Tight spacing          |
| spacing3  | 12px  | Standard small spacing |
| spacing4  | 16px  | Standard spacing       |
| spacing5  | 20px  | Comfortable spacing    |
| spacing6  | 24px  | Generous spacing       |
| spacing8  | 32px  | Large spacing          |
| spacing12 | 48px  | Section spacing        |

## Border Radius

| Token   | Value | Usage               |
| ------- | ----- | ------------------- |
| radius1 | 4px   | Small elements      |
| radius2 | 8px   | Buttons, inputs     |
| radius3 | 12px  | Cards, containers   |
| radius4 | 16px  | Large cards, modals |

## Shadows

### Card Shadow (Standard)

```dart
BoxShadow(
  color: Colors.black.withOpacity(0.08),
  blurRadius: 12,
  offset: Offset(0, 2),
),
BoxShadow(
  color: Colors.black.withOpacity(0.12),
  blurRadius: 24,
  offset: Offset(0, 8),
  spreadRadius: -4,
)
```

### Card Shadow Elevated (Interactive)

```dart
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 16,
  offset: Offset(0, 4),
),
BoxShadow(
  color: Colors.black.withOpacity(0.15),
  blurRadius: 32,
  offset: Offset(0, 12),
  spreadRadius: -6,
)
```

## Component Guidelines

### Page Structure

Every page follows this pattern:

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.backgroundGradient,
  ),
  child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    body: // content
  ),
)
```

### Cards

White cards with shadows on gradient background:

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radius3),
    boxShadow: AppTheme.cardShadow,
  ),
  child: // content
)
```

### Buttons on Gradient

- **Primary**: White background, navy text
- **Secondary/Outlined**: Transparent with white border and text
- **Danger**: White background with red border and text

### Form Inputs

White background with shadow, no border:

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radius2),
    boxShadow: AppTheme.cardShadow,
  ),
  child: TextField(
    decoration: InputDecoration(
      border: InputBorder.none,
    ),
  ),
)
```

### Event Type Indicators

Color-coded left bar on event cards:

- **Appointments**: `brandBlueLight` (#64B5F6)
- **Medications**: `brandTeal` (#57B4A4)
- **Symptoms**: Orange (#F59E0B)

### Bottom Navigation

- Background: Navy 500 (`#1B2A41`)
- Selected: White
- Unselected: White at 60% opacity

### Tab Selectors

White container with shadow, animated dark navy indicator:

- Selected tab: Navy background, white icon
- Unselected: Transparent, dark icon

## Usage in Flutter

```dart
import 'package:vet_plus/theme/app_theme.dart';

// Background gradient
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.backgroundGradient,
  ),
)

// White card
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radius3),
    boxShadow: AppTheme.cardShadow,
  ),
)

// Text on gradient
Text(
  'Title',
  style: TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  ),
)

// Text in card
Text(
  'Content',
  style: TextStyle(
    color: AppTheme.primary,
  ),
)

// Spacing
SizedBox(height: AppTheme.spacing4)
Gap(AppTheme.spacing3)
```

## Usage in React/Web

```javascript
import tokens from './design_tokens.json';

// Background gradient
background: tokens.colors.background.gradient

// Card styles
backgroundColor: tokens.colors.background.card,
borderRadius: tokens.borderRadius['4'],
boxShadow: tokens.shadows.card.join(', ')

// Text on gradient
color: tokens.colors.text.onGradient

// Text in card
color: tokens.colors.text.onCard
```

## Accessibility

- White cards on dark gradient: High contrast (>7:1)
- Navy text on white cards: High contrast (>7:1)
- White text on gradient: High contrast (>4.5:1)
- All interactive elements meet WCAG AA standards

## Updates

When updating the design system:

1. Update `app_theme.dart` for Flutter implementation
2. Update `design_tokens.json` for web/cross-platform tokens
3. Update this README with any new guidelines
4. Ensure both platforms maintain visual consistency
