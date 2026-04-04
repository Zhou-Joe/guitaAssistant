# Guitar Tool App Design Specification

> Cross-platform guitar practice companion app for iOS and Android

**Version:** 1.0  
**Date:** 2026-04-04  
**Platform:** Flutter (iOS + Android)

---

## 1. Overview

### 1.1 Purpose

A pure local guitar practice tool app that helps users track their guitar skill development through tuning, metronome practice, tab storage, recording, and audio analysis.

### 1.2 Target Users

Guitar players who want an all-in-one practice companion that works completely offline with vivid, friendly UI.

### 1.3 Key Features

1. **调音 (Tuner)** - 6-string guitar tuner with animated guidance
2. **节拍器 (Metronome)** - BPM control with 变速 (tempo change) modes
3. **收藏夹 (Favorites)** - Guitar tab storage (PDFs/photos) with folders + tags
4. **Recording** - Audio-only or video mode, share to gallery/social apps
5. **Analysis** - Rhythm alignment visualization, pitch detection, 节奏 analysis
6. **AI API** - User-configurable multimodal API endpoint

---

## 2. Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Home Screen                           │   │
│  │  [Tuner] [Metronome] [Favorites] [Record] [Analyze]     │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                     Feature Modules Layer                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────┐ │
│  │  Tuner   │ │Metronome │ │Favorites │ │ Recording│ │ AI   │ │
│  │ Screen   │ │ Screen   │ │ Screen   │ │ Screen   │ │Screen│ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────┘ │
├─────────────────────────────────────────────────────────────────┤
│                      Business Logic Layer                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Services: TunerService, MetronomeService, AudioService  │  │
│  │          AnalysisService, StorageService, AIService      │  │
│  └──────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                        Data Layer                               │
│  ┌─────────────────┐  ┌─────────────────────────────────────┐  │
│  │   Hive DB       │  │   Local File Storage                │  │
│  │   - Tabs        │  │   - PDF files                       │  │
│  │   - Folders     │  │   - Tab images                      │  │
│  │   - Tags        │  │   - Audio recordings (.m4a)         │  │
│  │   - Recordings  │  │   - Video recordings (.mp4)         │  │
│  │   - Settings    │  │   - App sandbox directory           │  │
│  └─────────────────┘  └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 State Management

**Provider** for state management:
- Simple, well-documented
- Good for this app's complexity level
- Easy to test and maintain

### 2.3 Module Boundaries

Each feature module is self-contained:
- Own screens, widgets, services
- Communicates via well-defined interfaces
- Can be tested independently

---

## 3. Feature Specifications

### 3.1 Tuner (调音)

**Responsibility:** Detect pitch and guide user to tune 6 guitar strings.

**User Flow:**
1. User opens Tuner screen
2. App listens to microphone input
3. Detects frequency and maps to nearest guitar string note
4. Displays animated guidance (tighten/loosen)
5. Visual feedback when in tune

**Standard Tuning:**
| String | Note | Frequency |
|--------|------|-----------|
| 6th (thickest) | E2 | 82.41 Hz |
| 5th | A2 | 110.00 Hz |
| 4th | D3 | 146.83 Hz |
| 3rd | G3 | 196.00 Hz |
| 2nd | B3 | 246.94 Hz |
| 1st (thinnest) | E4 | 329.63 Hz |

**UI Components:**
- Animated string indicator (shows which string detected)
- Directional animation (arrow up for "tighten", down for "loosen")
- Color feedback: red (flat/sharp) → yellow (close) → green (in tune)
- Tolerance: ±5 cents for "in tune"

**Technical:**
- Package: `flutter_detect_pitch`
- Sample rate: 44100 Hz
- Update frequency: ~30fps for smooth animation

---

### 3.2 Metronome (节拍器)

**Responsibility:** Provide accurate rhythm guidance with tempo variation modes.

**Core Features:**
- BPM: 30-250 range
- Time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8
- Accent on first beat of measure
- Visual + audio feedback

**变速 (Tempo Change) Modes:**

| Mode | Description | Use Case |
|------|-------------|----------|
| **Manual** | Fixed BPM | Standard metronome |
| **Gradual** | BPM increases/decreases by X every N bars | Speed training |
| **Step** | Predefined BPM sequence (e.g., 60→80→100) | Section practice |
| **Interval** | Alternate between two BPMs | Rhythm variation practice |

**UI Components:**
- Large BPM display with +/- buttons
- Tap tempo button
- Time signature selector
- Mode selector + configuration panel
- Visual beat indicator (pulsing circle)

**Technical:**
- Package: `metronome` v2.0.6+
- Audio click: short, clear tone (configurable)
- Timing accuracy: ±1ms

---

### 3.3 Favorites (收藏夹)

**Responsibility:** Store and organize guitar tabs (PDFs, photos).

**Data Model:**

```
Folder
├── id: String
├── name: String
├── parentId: String? (for nested folders)
├── createdAt: DateTime
└── children: Folder[]

Tab
├── id: String
├── title: String
├── filePath: String (local path)
├── fileType: PDF | IMAGE
├── folderId: String
├── tags: String[]
├── createdAt: DateTime
├── updatedAt: DateTime
└── isFavorite: bool
```

**Features:**
- Create/rename/delete folders (nested supported)
- Add tags to tabs
- Search by title or tag
- Grid/list view toggle
- Quick preview on tap

**UI Components:**
- Folder browser (breadcrumb navigation)
- Tab card with thumbnail
- Tag chips
- Multi-select for batch operations

**Technical:**
- Database: Hive (folders, tabs, tags)
- Storage: App sandbox `/documents/tabs/`
- Package: `file_picker` for import

---

### 3.4 Recording

**Responsibility:** Record practice sessions in audio-only or video mode.

**Recording Modes:**

| Mode | Format | Use Case |
|------|--------|----------|
| **Audio** | .m4a (AAC), 44.1kHz | Quick practice logs |
| **Video** | .mp4 (H.264), 1080p30 | Full performance capture |

**Features:**
- Mode selector before recording
- Recording timer display
- Pause/resume support
- Recording list with metadata (date, duration)
- Playback within app

**Sharing:**
- Export to device gallery
- Share sheet integration
- Direct share to WeChat, QQ

**UI Components:**
- Large record button
- Mode toggle (audio/video)
- Recording list with play/preview
- Share button on each recording

**Technical:**
- Audio: `record` package
- Video: `camera` package
- Sharing: `share_plus`, `gallery_saver`
- Storage: App sandbox `/recordings/`

---

### 3.5 Analysis

**Responsibility:** Analyze recordings and visualize rhythm/pitch accuracy.

**Analysis Modes:**

| Mode | Visualization | Description |
|------|---------------|-------------|
| **Waveform + Beats** | Waveform with beat markers | See where beats fall on recording |
| **Timeline Comparison** | Expected vs actual timing | Side-by-side beat alignment |
| **Precision Heatmap** | Color-coded accuracy timeline | Red (off) to green (on beat) |

**Metrics:**
- Timing deviation (ms from beat)
- Consistency score (% of beats within tolerance)
- Detected tempo vs target tempo
- Note/pitch accuracy (for melodic passages)

**Rhythm Alignment Algorithm:**
1. Detect transients in recording
2. Map transients to expected beat positions
3. Calculate deviation for each beat
4. Generate visualization data

**Pitch Detection:**
- FFT-based frequency analysis
- Map detected frequencies to notes
- Show pitch accuracy over time

**UI Components:**
- Recording selector
- Mode switcher (3 visualization types)
- Interactive timeline (scrub to hear position)
- Score summary cards

**Technical:**
- Audio analysis: `audio_analyzer`, `flutter_fft`
- FFT size: 2048 samples
- Visualization: Custom Painter widgets

---

### 3.6 AI API (Pluggable)

**Responsibility:** Provide configurable interface for future AI features.

**Configuration:**
- API Endpoint URL (user input)
- API Key (secure storage)
- Model Name (user input)

**Settings Screen:**
- Endpoint text field
- API key text field (masked)
- Model name text field
- Test connection button
- Enable/disable toggle

**Use Cases (Future):**
- Tab transcription from audio
- Chord detection
- Practice feedback
- Technique analysis

**Technical:**
- Storage: Hive (encrypted box for API key)
- HTTP client: `http` or `dio`
- No hardcoded endpoints - fully user-configurable

---

## 4. UI/UX Design

### 4.1 Theme: Playful & Colorful

**Color Palette:**

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | #FF6B6B | Buttons, accents |
| Secondary | #4ECDC4 | Secondary actions |
| Success | #95E1D3 | In-tune, correct |
| Warning | #FFE66D | Close, caution |
| Error | #FF8585 | Flat/sharp, error |
| Background | #F7FFF7 | Main background |
| Card | #FFFFFF | Card backgrounds |
| Text | #2D3436 | Primary text |

**Typography:**
- Headings: Nunito (rounded, friendly)
- Body: Noto Sans (readable)
- Numbers: Nunito (for BPM, tuning)

**UI Elements:**
- Border radius: 16px (cards), 24px (buttons)
- Shadows: Soft, diffused (elevation 2-4)
- Icons: Rounded, outlined style
- Animations: Bouncy, elastic easing

### 4.2 Navigation

**Bottom Navigation Bar:**
- Home (dashboard)
- Tuner
- Metronome
- Favorites
- Record & Analyze

**Home Dashboard:**
- Quick access cards to all features
- Recent recordings
- Quick practice button

### 4.3 Animations

- Page transitions: Slide with fade
- Button press: Scale down 0.95
- Tuner animation: Smooth needle/image movement
- Metronome pulse: Scale + color pulse on beat
- Recording: Pulsing ring animation

---

## 5. Data Model

### 5.1 Hive Boxes

```dart
// Box: settings
{
  "tuner_tolerance": 5, // cents
  "metronome_bpm": 120,
  "metronome_time_signature": "4/4",
  "recording_quality": "high",
  "ai_api_enabled": false,
}

// Box: folders
{
  "folder_id": {
    "id": "folder_id",
    "name": "My Songs",
    "parentId": null,
    "createdAt": "2026-04-04T10:00:00Z",
  }
}

// Box: tabs
{
  "tab_id": {
    "id": "tab_id",
    "title": "Wonderwall",
    "filePath": "/path/to/file.pdf",
    "fileType": "PDF",
    "folderId": "folder_id",
    "tags": ["oasis", "beginner", "rock"],
    "createdAt": "2026-04-04T10:00:00Z",
    "updatedAt": "2026-04-04T10:00:00Z",
    "isFavorite": true,
  }
}

// Box: recordings
{
  "recording_id": {
    "id": "recording_id",
    "title": "Practice Session 1",
    "filePath": "/path/to/recording.m4a",
    "mode": "audio", // or "video"
    "duration": 180, // seconds
    "createdAt": "2026-04-04T10:00:00Z",
  }
}

// Box: ai_config (encrypted)
{
  "api_endpoint": "",
  "api_key": "", // encrypted
  "model_name": "",
}
```

### 5.2 File Structure

```
App Sandbox/
├── documents/
│   ├── tabs/
│   │   └── {tab_id}.{pdf|jpg|png}
│   ├── recordings/
│   │   ├── audio/
│   │   │   └── {recording_id}.m4a
│   │   └── video/
│   │       └── {recording_id}.mp4
│   └── analysis/
│       └── {recording_id}_analysis.json
└── hive/
    ├── settings.box
    ├── folders.box
    ├── tabs.box
    ├── recordings.box
    └── ai_config.box (encrypted)
```

---

## 6. Error Handling

### 6.1 Permission Errors

| Permission | Handle |
|------------|--------|
| Microphone | Show settings dialog, explain why needed |
| Camera | Show settings dialog, explain why needed |
| Storage | Show settings dialog for file access |

### 6.2 Audio Errors

- Mic unavailable: Show friendly message, retry button
- Recording failed: Save partial recording if possible
- Analysis failed: Show error, allow re-try

### 6.3 File Errors

- File not found: Remove from database, notify user
- Import failed: Show error message with reason

---

## 7. Testing Strategy

### 7.1 Unit Tests

- Services (TunerService, MetronomeService, etc.)
- Data models
- Utility functions

### 7.2 Widget Tests

- All screen widgets
- Custom widgets (tuner display, beat indicator)
- User interactions

### 7.3 Integration Tests

- Recording flow
- Tab import flow
- Metronome start/stop

---

## 8. Dependencies

### 8.1 Core

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | latest | UI framework |
| provider | ^6.1.1 | State management |
| hive | ^2.2.3 | Local database |
| hive_flutter | ^1.1.0 | Hive Flutter integration |

### 8.2 Audio

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_detect_pitch | ^0.0.5 | Pitch detection |
| metronome | ^2.0.6 | Metronome engine |
| record | ^5.0.4 | Audio recording |
| audio_analyzer | ^0.1.1 | Audio analysis |
| flutter_fft | ^1.0.0 | FFT processing |

### 8.3 Media

| Package | Version | Purpose |
|---------|---------|---------|
| camera | ^0.10.5 | Video recording |
| video_player | ^2.8.2 | Playback |
| gallery_saver | ^2.3.2 | Export to gallery |
| share_plus | ^7.2.1 | Share sheet |

### 8.4 Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| file_picker | ^6.1.1 | Import files |
| permission_handler | ^11.2.0 | Permission management |
| path_provider | ^2.1.2 | File paths |
| http | ^1.2.0 | HTTP client |
| encrypt | ^5.0.3 | API key encryption |

---

## 9. Platform Configuration

### 9.1 iOS (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string> microphone is needed for tuner, metronome, and recording features</string>
<key>NSCameraUsageDescription</key>
<string>Camera is needed for video recording</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to save and share recordings</string>
```

### 9.2 Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## 10. Future Considerations

### 10.1 Potential AI Features

- Automatic chord detection from recording
- Tab transcription (audio → sheet music)
- Technique feedback (rhythm consistency, dynamics)
- Practice recommendations

### 10.2 Potential Premium Features

- Cloud sync (optional, user-enabled)
- Advanced analysis metrics
- Lesson integration
- Backing track library

---

## 11. Success Criteria

- [ ] All 6 core features functional
- [ ] Works completely offline (except optional AI API)
- [ ] No crashes during recording/analysis
- [ ] Metronome timing accuracy ±5ms
- [ ] Tuner accuracy ±5 cents
- [ ] Smooth 60fps animations
- [ ] App size < 50MB (initial install)
