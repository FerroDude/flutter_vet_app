# Peton Design System

This design system provides a consistent visual language for both the Flutter mobile app and React web application.

## Files Structure

- `app_theme.dart` - Flutter theme implementation
- `design_tokens.json` - Platform-agnostic design tokens for React
- `README.md` - This documentation

## Color Palette

### Primary Colors

- **Primary Blue**: `#2563EB` - Main brand color, used for primary actions and branding
- **Primary Blue Dark**: `#1D4ED8` - Hover states and emphasis
- **Primary Blue Light**: `#3B82F6` - Light accents and secondary elements

### Secondary Colors

- **Success Green**: `#10B981` - Health, success states, positive actions
- **Warning Orange**: `#F59E0B` - Alerts, warnings, attention-needed states
- **Accent Purple**: `#8B5CF6` - Special features, premium elements

### Semantic Colors

- **Success**: `#059669` - Success messages, completed states
- **Warning**: `#D97706` - Warning messages, caution states
- **Error**: `#DC2626` - Error messages, destructive actions
- **Info**: `#0284C7` - Informational messages, neutral highlights

## Typography

The design system uses system fonts for optimal performance and native feel:

- **Font Family**: System font stack (San Francisco on iOS, Roboto on Android, system fonts on web)
- **Scale**: Modular scale from 10px to 32px
- **Weights**: Light (300) to Extra Bold (800)

### Text Styles

- **Display Large**: 32px, Extra Bold - Hero text, main headings
- **Display Medium**: 28px, Bold - Section headings
- **Heading Large**: 24px, Semi Bold - Page titles
- **Heading Medium**: 20px, Semi Bold - Card titles, form sections
- **Heading Small**: 18px, Semi Bold - List items, small headings
- **Body Large**: 16px, Regular - Main content, descriptions
- **Body Medium**: 14px, Regular - Secondary content
- **Body Small**: 12px, Regular - Captions, metadata
- **Label Large**: 14px, Medium - Button text, form labels
- **Label Medium**: 12px, Medium - Small labels, tags
- **Label Small**: 10px, Medium - Tiny labels, badges

## Spacing

Based on 4px grid system:

- **1**: 4px - Minimal spacing
- **2**: 8px - Tight spacing
- **3**: 12px - Close spacing
- **4**: 16px - Standard spacing
- **5**: 20px - Comfortable spacing
- **6**: 24px - Generous spacing
- **8**: 32px - Large spacing
- **10**: 40px - Extra large spacing
- **12**: 48px - Section spacing
- **16**: 64px - Page spacing
- **20**: 80px - Hero spacing

## Border Radius

- **Small**: 8px - Tags, small buttons
- **Medium**: 12px - Cards, inputs, standard buttons
- **Large**: 16px - Modals, large containers
- **XLarge**: 24px - Hero elements, special containers

## Shadows

Three-tier shadow system:

- **Small**: Subtle elevation for cards and inputs
- **Medium**: Standard elevation for dropdowns and modals
- **Large**: High elevation for floating elements

## Component Guidelines

### Buttons

- **Primary**: Blue background, white text - Main actions
- **Secondary**: Blue border, blue text - Secondary actions
- **Tertiary**: Blue text only - Minimal actions

### Cards

- White background with light border and subtle shadow
- 12px border radius
- Consistent padding using spacing tokens

### Form Inputs

- Light gray background
- Blue focus border
- Consistent padding and border radius

## Usage in Flutter

```dart
import 'package:your_app/theme/app_theme.dart';

// Using colors
Container(color: AppTheme.primaryBlue)

// Using typography
Text('Hello', style: AppTheme.headingMedium)

// Using spacing
Padding(padding: EdgeInsets.all(AppTheme.spacing4))

// Using components
ElevatedButton(
  style: AppTheme.primaryButtonStyle,
  onPressed: () {},
  child: Text('Primary Action'),
)
```

## Usage in React (CSS-in-JS)

```javascript
import designTokens from './design_tokens.json';

const styles = {
  primaryButton: {
    backgroundColor: designTokens.colors.primary.blue,
    color: designTokens.colors.text.onPrimary,
    borderRadius: designTokens.borderRadius.medium,
    padding: `${designTokens.spacing[4]} ${designTokens.spacing[6]}`,
    fontSize: designTokens.typography.fontSize.labelLarge,
    fontWeight: designTokens.typography.fontWeight.medium,
  },
};
```

## Usage in React (CSS Variables)

```css
:root {
  --color-primary-blue: #2563eb;
  --color-text-primary: #111827;
  --spacing-4: 16px;
  --radius-medium: 12px;
}

.primary-button {
  background-color: var(--color-primary-blue);
  color: var(--color-text-on-primary);
  border-radius: var(--radius-medium);
  padding: var(--spacing-4) var(--spacing-6);
}
```

## Design Principles

1. **Clarity**: High contrast, readable typography, clear visual hierarchy
2. **Consistency**: Consistent spacing, colors, and component behavior
3. **Accessibility**: WCAG AA compliant color contrasts, touch targets
4. **Performance**: System fonts, optimized shadows, efficient rendering
5. **Scalability**: Modular tokens, reusable components, maintainable code

## Color Accessibility

All color combinations meet WCAG AA standards:

- Primary blue on white: 4.5:1 contrast ratio
- Text colors on backgrounds: 7:1+ contrast ratio
- Interactive elements: 3:1+ contrast ratio

## Updates and Maintenance

When updating the design system:

1. Update `app_theme.dart` for Flutter changes
2. Update `design_tokens.json` for React changes
3. Test both platforms for consistency
4. Update this README with any new guidelines
