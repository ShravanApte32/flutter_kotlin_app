# Flutter Camera App with Kotlin Integration

A Flutter application that integrates with Kotlin to record videos with overlay information and save them to the device gallery.

## Features

- **Camera Preview**: Real-time camera preview with video recording capabilities
- **Video Recording**: Start/stop video recording with visual indicators
- **Overlay Information**: Displays current date, time, latitude, and longitude on the video
- **Gallery Integration**: Saves recorded videos to device gallery using Kotlin native code
- **Location Services**: Automatically fetches GPS coordinates for overlay
- **Permissions Handling**: Manages camera, microphone, location, and storage permissions

## Architecture

### Flutter (Dart) Components:
- **Camera Management**: Uses the `camera` plugin for video recording
- **Location Services**: Uses the `geolocator` plugin for GPS coordinates
- **UI Components**: Custom overlay display and recording controls
- **Method Channel**: Communication bridge with Kotlin native code

### Kotlin (Android) Components:
- **Gallery Saving**: Native Android code to save videos to MediaStore
- **Method Channel Handler**: Receives video data from Flutter
- **Permissions**: Handles storage permissions at the native level

## Project Structure

```
camera_app/
├── lib/
│   └── main.dart                 # Main Flutter application
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml   # App permissions
│       └── kotlin/com/example/camera_app/
│           └── MainActivity.kt   # Kotlin native code
└── pubspec.yaml                  # Dependencies
```

## Dependencies

### Flutter Dependencies:
- `camera: ^0.10.5+5` - Camera functionality
- `geolocator: ^10.1.0` - Location services

### Android Permissions:
- `CAMERA` - Camera access
- `RECORD_AUDIO` - Audio recording
- `ACCESS_FINE_LOCATION` - GPS coordinates
- `ACCESS_COARSE_LOCATION` - Network-based location
- `WRITE_EXTERNAL_STORAGE` - Gallery writing
- `READ_EXTERNAL_STORAGE` - Gallery reading
- `READ_MEDIA_VIDEO` - Android 10+ media access

## Setup Instructions

### Prerequisites:
1. Flutter SDK installed
2. Android Studio with Android SDK
3. Physical Android device or emulator

### Installation:
1. Clone or download the project
2. Navigate to the project directory:
   ```bash
   cd camera_app
   ```
3. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Connect your Android device or start an emulator
5. Run the application:
   ```bash
   flutter run
   ```

## Usage

1. **Launch the App**: The camera preview will start automatically
2. **Grant Permissions**: Allow camera, microphone, location, and storage access
3. **View Overlay**: The top-left corner shows current date/time and GPS coordinates
4. **Start Recording**: Tap the blue camera button to start recording
5. **Recording Indicator**: A red "REC" indicator appears during recording
6. **Stop Recording**: Tap the red stop button to end recording
7. **Automatic Saving**: The video is automatically saved to the device gallery with overlay information

## Technical Implementation

### Method Channel Communication:
```dart
static const platform = MethodChannel('com.example.camera_app/gallery');

await platform.invokeMethod('saveVideoToGallery', {
  'videoPath': videoPath,
  'dateTime': _currentDateTime,
  'latitude': _currentPosition?.latitude ?? 0.0,
  'longitude': _currentPosition?.longitude ?? 0.0,
});
```

### Kotlin Gallery Saving:
```kotlin
private fun saveVideoToGallery(
    videoPath: String,
    dateTime: String,
    latitude: Double,
    longitude: Double
): Uri?
```

### Overlay Implementation:
The overlay is rendered as a Flutter widget positioned over the camera preview, showing:
- Current date and time (updated every second)
- GPS latitude and longitude (6 decimal places)
- Recording status indicator

## Key Features Explained

### 1. Camera Integration
- Uses Flutter's `camera` plugin for cross-platform camera access
- Supports high-resolution video recording
- Real-time preview with overlay rendering

### 2. Location Services
- Automatic GPS coordinate fetching
- Permission handling for location access
- Fallback handling for location unavailable scenarios

### 3. Native Gallery Saving
- Kotlin implementation for Android MediaStore integration
- Proper handling of Android 10+ scoped storage
- Metadata inclusion (location, timestamp)
- Automatic cleanup of temporary files

### 4. Method Channel Bridge
- Seamless communication between Flutter and Kotlin
- Error handling and result callbacks
- Type-safe parameter passing

## Troubleshooting

### Common Issues:

1. **Camera Permission Denied**
   - Ensure permissions are granted in device settings
   - Check AndroidManifest.xml for proper permission declarations

2. **Location Not Available**
   - Enable GPS/Location services on device
   - Grant location permissions to the app

3. **Video Not Saving**
   - Check storage permissions
   - Ensure sufficient storage space
   - Verify MediaStore access permissions

4. **Build Errors**
   - Run `flutter clean` and `flutter pub get`
   - Check Android SDK and build tools versions
   - Ensure proper Kotlin version compatibility

## Future Enhancements

- Support for front/rear camera switching
- Video quality selection options
- Custom overlay styling and positioning
- Batch video processing
- Cloud storage integration
- iOS platform support

## License

This project is created for educational purposes and demonstrates Flutter-Kotlin integration patterns.

