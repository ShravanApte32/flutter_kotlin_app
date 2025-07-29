# Detailed Setup Guide

## Step-by-Step Installation

### 1. Environment Setup

#### Install Flutter SDK:
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:/path/to/flutter/bin"

# Verify installation
flutter doctor
```

#### Install Android Studio:
1. Download Android Studio from https://developer.android.com/studio
2. Install Android SDK and build tools
3. Set up Android emulator or connect physical device

### 2. Project Setup

#### Clone and Configure:
```bash
# Navigate to your development directory
cd /your/development/path

# Copy the camera_app project files
# Ensure all files are in place:
# - lib/main.dart
# - android/app/src/main/kotlin/com/example/camera_app/MainActivity.kt
# - android/app/src/main/AndroidManifest.xml
# - pubspec.yaml

# Install dependencies
flutter pub get
```

### 3. Android Configuration

#### Verify AndroidManifest.xml permissions:
```xml
<!-- Camera permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Location permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Storage permissions -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

### 4. Device Setup

#### For Physical Device:
1. Enable Developer Options:
   - Go to Settings > About Phone
   - Tap Build Number 7 times
2. Enable USB Debugging:
   - Go to Settings > Developer Options
   - Turn on USB Debugging
3. Connect device via USB
4. Verify connection: `flutter devices`

#### For Emulator:
1. Open Android Studio
2. Go to AVD Manager
3. Create new virtual device
4. Choose device with camera support
5. Start emulator

### 5. Running the Application

```bash
# Check connected devices
flutter devices

# Run on connected device
flutter run

# Run in debug mode
flutter run --debug

# Run in release mode
flutter run --release
```

### 6. Testing Checklist

#### Initial Launch:
- [ ] App opens without crashes
- [ ] Camera preview displays
- [ ] Permission dialogs appear

#### Permission Testing:
- [ ] Camera permission granted
- [ ] Microphone permission granted
- [ ] Location permission granted
- [ ] Storage permission granted

#### Functionality Testing:
- [ ] Camera preview works
- [ ] Overlay displays date/time
- [ ] Overlay displays GPS coordinates
- [ ] Recording starts/stops properly
- [ ] Recording indicator appears
- [ ] Video saves to gallery
- [ ] Success message displays

### 7. Troubleshooting

#### Build Issues:
```bash
# Clean build
flutter clean
flutter pub get

# Check Flutter doctor
flutter doctor

# Rebuild
flutter run
```

#### Permission Issues:
1. Manually grant permissions in device settings
2. Restart the app
3. Check AndroidManifest.xml syntax

#### Camera Issues:
1. Test on physical device (emulator cameras may be limited)
2. Check camera permissions
3. Verify camera plugin version compatibility

#### Location Issues:
1. Enable GPS on device
2. Test outdoors for better GPS signal
3. Check location permissions

### 8. Development Tips

#### Debugging:
```bash
# View logs
flutter logs

# Debug on device
flutter run --debug

# Profile performance
flutter run --profile
```

#### Code Modifications:
- Main Flutter code: `lib/main.dart`
- Kotlin native code: `android/app/src/main/kotlin/com/example/camera_app/MainActivity.kt`
- Dependencies: `pubspec.yaml`
- Permissions: `android/app/src/main/AndroidManifest.xml`

#### Testing on Different Devices:
- Test on various Android versions
- Test on different screen sizes
- Verify camera orientations
- Check storage locations

### 9. Common Error Solutions

#### "Camera permission denied":
```dart
// Add permission request handling
await Permission.camera.request();
```

#### "Location services disabled":
```dart
// Check location services
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
```

#### "Failed to save video":
```kotlin
// Check storage permissions in Kotlin
if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
    != PackageManager.PERMISSION_GRANTED) {
    // Request permission
}
```

### 10. Performance Optimization

#### Video Quality:
```dart
// Adjust resolution in camera controller
_controller = CameraController(
  widget.cameras[0],
  ResolutionPreset.medium, // Change from high to medium for better performance
);
```

#### Location Updates:
```dart
// Reduce location update frequency
LocationSettings locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10,
);
```

This setup guide should help you get the Flutter camera app running successfully with Kotlin integration for gallery saving functionality.

