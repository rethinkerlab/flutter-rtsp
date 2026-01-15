# RTSP Viewer - Flutter App

A Flutter application for viewing RTSP video streams.

## Features

- Real-time RTSP video streaming
- Play/Pause controls
- Reconnect functionality
- Error handling with retry capability
- Landscape and portrait support
- Hardware acceleration

## RTSP Stream Configuration

The app is configured to connect to:
```
rtsp://admin:hkezit_root@61.238.85.218/rtsp/streaming?channel=03
```

To change the RTSP URL, edit the `rtspUrl` variable in `lib/main.dart`:

```dart
final String rtspUrl = 'your-rtsp-url-here';
```

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio or Xcode
- For Android: Android SDK with minimum SDK 21
- For iOS: iOS 12.0 or higher

## Installation

1. Clone this repository or navigate to the project directory

2. Install dependencies:
```bash
flutter pub get
```

3. For Android, ensure you have a device/emulator running

4. Run the app:
```bash
flutter run
```

## Platform-Specific Setup

### Android

The app requires the following permissions (already configured in AndroidManifest.xml):
- INTERNET
- ACCESS_NETWORK_STATE

The app also uses `android:usesCleartextTraffic="true"` to allow non-HTTPS connections.

### iOS

For iOS, you need to add the following to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Dependencies

- `flutter_vlc_player`: ^7.4.0 - VLC-based media player for RTSP streaming
- `permission_handler`: ^11.0.1 - For handling runtime permissions

## Usage

1. Launch the app
2. The app will automatically attempt to connect to the configured RTSP stream
3. Use the Play/Pause button to control playback
4. Use the Stop button to stop the stream
5. Use the Refresh icon in the app bar to reconnect if the stream fails

## Troubleshooting

### Connection Issues

If you experience connection issues:
1. Verify the RTSP URL is correct and accessible from your network
2. Check that your device has internet connectivity
3. Ensure the RTSP server is running and accepting connections
4. Try tapping the Refresh button to reconnect

### Performance Issues

- The app uses hardware acceleration by default for better performance
- Network caching is set to 1000ms to balance between latency and smooth playback
- Adjust the `networkCaching` value in `main.dart` if needed

### Build Issues

If you encounter build issues:
1. Run `flutter clean`
2. Run `flutter pub get`
3. Rebuild the app

## Project Structure

```
rtsp_viewer/
├── lib/
│   └── main.dart              # Main application code with RTSP player
├── android/                   # Android-specific configuration
│   ├── app/
│   │   ├── build.gradle      # App-level Gradle config
│   │   └── src/
│   │       └── main/
│   │           ├── AndroidManifest.xml
│   │           └── kotlin/
│   │               └── com/example/rtsp_viewer/
│   │                   └── MainActivity.kt
│   ├── build.gradle          # Project-level Gradle config
│   └── settings.gradle       # Gradle settings
└── pubspec.yaml              # Flutter dependencies

```

## License

This project is provided as-is for demonstration purposes.
