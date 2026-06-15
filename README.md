# 📱 Chord iOS - Flutter Mobile Client

> **📄 Project Final Report**: The project final report is located in the repository's root directory: [21290270.pdf](./21290270.pdf)
> 
> **🎥 Project Introduction Video**: [YouTube - Chord iOS Project Introduction](https://youtu.be/59dusNjMBpM)

Chord iOS is a Flutter-based mobile client for the [Chord](https://github.com/brckfrc/chord) project. This app uses the API from the Chord backend project. A Discord-like real-time chat application with iOS and Android support, platform-specific features, permission management, lifecycle handling, and notification support.

## 🚀 Features

- **Real-Time Messaging**: Instant messaging via SignalR WebSockets
- **Guilds & Channels**: Create and manage Discord-like servers with text and voice channels
- **Direct Messages**: Private messaging support
- **Mentions**: @mention system with autocomplete and notifications
- **User Presence**: Online, Idle, DND, Invisible statuses
- **Offline Mode**: Message caching, pending queue, and sync logic
- **Optimistic Updates**: Ghost messages for instant feedback

## 🛠️ Tech Stack

### Core

- **Flutter 3.38+** - Cross-platform UI framework
- **Dart 3.10+** - Programming language
- **Riverpod 2.5** - State management
- **GoRouter 13.2** - Declarative routing

### Network & Real-time

- **Dio 5.4** - HTTP client
- **SignalR Core 1.0** - Real-time WebSocket communication

### Storage & Database

- **flutter_secure_storage 9.0** - Secure token storage (Keychain)
- **Hive 2.2** - Local database (offline cache)

### Utilities

- **Sentry Flutter 8.0** - Error tracking & crash reporting
- **connectivity_plus 6.0** - Network connectivity monitoring

## 📋 Prerequisites

### Development

- **Flutter SDK 3.38+** - [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Xcode 15+** (macOS only) - iOS development
- **CocoaPods** - iOS dependency manager
- **Android Studio** - Android development (Android SDK, Gradle)
- **VS Code** - IDE (optional)

### Runtime

- **iOS 13.0+** - Minimum iOS version
- **Android 5.0+ (API 21+)** - Minimum Android version
- **Backend API** - Chord backend API must be running

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/brckfrc/chord_ios.git
cd chord_ios
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Backend API Connection

The app uses environment-based configuration. By default, it runs in **development mode** and connects to `localhost:5049`.

**Development Mode (Default):**

- API: `http://localhost:5049/api`
- SignalR: `http://localhost:5049`
- LiveKit: `ws://localhost:7880`

**Production Mode:**

- API: `https://chord.borak.dev/api`
- SignalR: `https://chord.borak.dev`
- LiveKit: `wss://chord.borak.dev:7880`

**Important Notes:**

- `apiBaseUrl` **must include `/api` prefix** (e.g., `http://localhost:5049/api`)
- `signalRBaseUrl` **must not include trailing slash** (e.g., `http://localhost:5049`)
- Configuration is in `lib/core/config/app_config.dart` (no manual editing needed)
- Environment is set via `--dart-define=ENV=production` flag

### 4. Run on iOS/Android Simulator or Device

```bash
# Development mode (default - connects to localhost)
flutter run -d ios          # iOS
flutter run -d android      # Android

# Production mode (connects to chord.borak.dev)
flutter run --dart-define=ENV=production -d ios
flutter run --dart-define=ENV=production -d android

# List available devices
flutter devices
flutter run -d <device-id>
```

**Note:** On a real device, `localhost` won't work in development mode. Use production mode or configure your computer's LAN IP address.

## 📁 Project Structure

```
chord_ios/
├── lib/                    # Flutter application code
│   ├── core/              # Core configuration
│   │   ├── config/        # App config (API URLs, environment)
│   │   ├── router/        # GoRouter route definitions
│   │   └── theme/         # Dark theme, colors
│   │
│   ├── features/          # Screens and UI components
│   │   ├── auth/         # Login, register screens
│   │   ├── guild/        # Guild management (sidebar, channel view)
│   │   ├── friends/      # DM (Direct Messages)
│   │   ├── messages/     # Message components (list, item, composer)
│   │   ├── mentions/     # Mention system
│   │   ├── modals/       # Modal dialogs (create guild, channel, invite)
│   │   ├── presence/     # User status (status update modal)
│   │   └── splash/       # Splash screen
│   │
│   ├── models/           # Data models (DTOs)
│   ├── repositories/     # API calls
│   ├── providers/        # State management (Riverpod)
│   ├── services/         # Services (API, database, SignalR, storage)
│   ├── shared/           # Shared widgets
│   └── main.dart         # Application entry point
│
├── ios/                   # iOS platform-specific code
├── android/               # Android platform-specific code
├── pubspec.yaml           # Flutter dependencies
└── README.md              # This file
```

## 🔧 Development

### Hot Reload

```bash
# Run in development mode (hot reload enabled)
flutter run

# Hot reload: Press `r`
# Hot restart: Press `R`
# Quit: Press `q`
```

### Build

#### iOS Build

```bash
# iOS Debug build (development mode)
flutter build ios --debug

# iOS Release build (development mode)
flutter build ios --release

# iOS Release build (production mode - for TestFlight/App Store)
flutter build ios --dart-define=ENV=production --release
```

#### Android Build

```bash
# Android Debug build (development mode)
flutter build apk --debug

# Android Release build (development mode)
flutter build apk --release

# Android Release build (production mode)
flutter build apk --dart-define=ENV=production --release

# Android App Bundle (for Google Play Store)
flutter build appbundle --dart-define=ENV=production --release
```

**Production Build Notes:**

- Always use `--dart-define=ENV=production` for production builds
- Production builds connect to `chord.borak.dev` automatically
- For Xcode builds, add environment variable: `ENV=production` in scheme settings (Edit Scheme → Run → Arguments → Environment Variables)

### Code Generation (Hive)

```bash
# Hive model code generation
flutter pub run build_runner build

# Watch mode (auto-generate)
flutter pub run build_runner watch
```

## 🔐 Platform Configuration

### iOS Configuration

#### Info.plist Permissions

Required permissions in `ios/Runner/Info.plist`:

```xml
<!-- Microphone (for voice channels) -->
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for voice channels.</string>

<!-- Camera (for video sharing) -->
<key>NSCameraUsageDescription</key>
<string>Camera access is required for video sharing.</string>

<!-- Photo Library (for image/video sharing) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required for sharing images and videos.</string>
```

#### Background Modes

In `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string> <!-- For voice channels -->
</array>
```

### Android Configuration

#### AndroidManifest.xml Permissions

Required permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Microphone (for voice channels) -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Camera (for video sharing) -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Photo Library (for image/video sharing) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Internet (for API calls) -->
<uses-permission android:name="android.permission.INTERNET" />
```

#### Background Service (for Voice Channels)

For voice channels, foreground service permission is required in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
```

## 📡 Backend Connection

This mobile app works with the [Chord](https://github.com/brckfrc/chord) backend project and uses its API.

### Backend Requirements

- Backend API must be running (default: `http://localhost:5049`)
- SignalR hubs must be active (`/hubs/chat`, `/hubs/presence`)
- CORS settings must be configured for mobile app

### Backend Setup

For backend setup, see the main repository: [Chord Backend README](../chord/backend/README.md)

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests (coming soon)
flutter test integration_test/
```

## 🔜 Upcoming Features

- **Voice Channels**: WebRTC P2P voice channels (≤5 users)
- **File Upload**: Image and video sharing
- **Push Notifications**: APNs/FCM integration
- **Video Support**: Inline video playback
- **UX Polish**: Accessibility, error handling, performance optimization
- **App Store**: Production build, testing, submission

## 🐛 Troubleshooting

### iOS Build Issues

```bash
# Update CocoaPods
cd ios
pod deintegrate
pod install
cd ..

# Flutter clean
flutter clean
flutter pub get
```

### Android Build Issues

> **Note**: Android CI builds (GitHub Actions) are currently disabled. This was done to save CI resources since iOS is the primary target, and because some plugins like `flutter_webrtc` require `compileSdk` updates that complicate the build. 
> **To re-enable**: Uncomment the `push` and `pull_request` triggers and remove the `if: false` condition in `.github/workflows/android-build.yml`. If you encounter a `compileSdk` error after re-enabling, you must globally force `compileSdkVersion 34` in the root `android/build.gradle` using a `subprojects { ... }` block.

```bash
# Clean Gradle cache
cd android
./gradlew clean
cd ..

# Flutter clean
flutter clean
flutter pub get

# Rebuild
flutter build apk --release
```

### SignalR Connection Issues

- Ensure backend API is running
- `signalRBaseUrl` must not include trailing slash
- Check CORS settings

### Secure Storage Issues

- Keychain may have issues on iOS Simulator
- Test on a real device

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Backend Repository**: [Chord Backend](https://github.com/brckfrc/chord)
