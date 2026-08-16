# Guitar Assistant Design System

## Overview

This design system provides harmonized UI guidelines for the Guitar Assistant Flutter app - a music/guitar practice tool.

## Style: Vibrant & Block-based

- **Keywords:** Bold, energetic, playful, block layout, geometric shapes, high color contrast
- **Best For:** Music apps, entertainment, creative tools
- **Mood:** Professional yet engaging for musicians

## Color Palette

| Role | Color | Usage |
|------|-------|-------|
| Primary | `#1E1B4B` (Indigo 950) | Headers, accents, primary actions |
| Secondary | `#4338CA` (Indigo 700) | Secondary elements, hover states |
| CTA/Success | `#22C55E` (Green 500) | Play buttons, success states, in-tune indicator |
| Error/Stop | `#EF4444` (Red 500) | Stop buttons, error states, out-of-tune indicator |
| Background | `#0F0F23` (Dark navy) | App background |
| Surface | `#1A1A2E` | Cards, panels, elevated surfaces |
| Surface Elevated | `#252542` | Modal backgrounds, dialogs |
| Text Primary | `#F8FAFC` (Slate 50) | Main text |
| Text Secondary | `#94A3B8` (Slate 400) | Muted text, subtitles |
| Text Muted | `#64748B` (Slate 500) | Labels, hints |

## Typography

- **Display Font:** Poppins (Headings, titles) - weights 600-700
- **Body Font:** Poppins (Body text) - weights 400-500
- **Sizes:** Display 24-32px, Title 18-20px, Body 14-16px, Caption 12px

## Key Effects

- **Spacing:** Generous gaps (16-24px between sections)
- **Rounding:** Cards rounded 16-20px, buttons rounded 24-28px (pill shape)
- **Shadows:** Subtle elevation (4-8px shadow radius)
- **Transitions:** 200-300ms for animations
- **Gradients:** Subtle vertical gradients on backgrounds

## UI Patterns by Screen

### Home Screen
- Grid layout (2 columns on mobile, 3 on tablet)
- Cards with icon + title + subtitle
- Hover/tap: scale 0.98, color shift
- Each card has distinct accent color from palette

### Tuner Screen
- Circular gauge display for pitch visualization
- 6 string buttons in vertical list
- Color feedback: green (in tune), red (out), neutral (waiting)
- Large start/stop button at bottom

### Metronome Screen
- BPM dial/slider at top
- Time signature selector (horizontal chips)
- Sound selector (dropdown or chips)
- Tempo mode panel
- Large circular play button

### Favorites Screen
- Folder grid or list view
- Card thumbnails with folder name
- Search/filter bar at top

### Recording Screen
- Tab bar (Audio/Video)
- Recording list with waveform preview
- Floating action button for new recording
- Player controls inline

### Analysis Screen
- Tab bar (Waveform/Timeline/Heatmap)
- Visualizations with dark background
- Chart colors from primary palette

### Settings Screen
- Grouped settings in cards
- Toggle switches with accent color
- Navigation items with icons

## Pre-Delivery Checklist

- [ ] All icons use Flutter Icons or custom SVG (no emojis as icons)
- [ ] Touch targets minimum 48x48px
- [ ] Smooth transitions (200-300ms)
- [ ] Dark theme colors applied consistently
- [ ] Loading states implemented
- [ ] Error feedback near problem source
- [ ] Focus states for accessibility

## Flutter Implementation Notes

```dart
// Theme definition
class AppColors {
  static const Color primary = Color(0xFF1E1B4B);
  static const Color secondary = Color(0xFF4338CA);
  static const Color cta = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFF0F0F23);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceElevated = Color(0xFF252542);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}
```

## Agent Instructions

Each agent working on a screen must:
1. Apply the dark color palette from this spec
2. Use Poppins font family
3. Maintain consistent spacing and rounding
4. Ensure touch targets are 48x48px minimum
5. Implement smooth transitions (200-300ms)
6. Reference other screens for pattern consistency