import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: null,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({Key? key, required this.cameras}) : super(key: key);
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _videoPath;
  Position? _currentPosition;
  String _currentDateTime = '';
  Timer? _dateTimeTimer;
  String _processingStatus = '';
  double _processingProgress = 0.0;

  static const platform = MethodChannel('com.example.camera_app/gallery');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _getCurrentLocation();
    _startDateTimeUpdates();
    _testFFmpeg();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimeTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: true,
      );

      try {
        await _controller!.initialize();
        if (mounted) setState(() {});
      } catch (e) {
        print('Error initializing camera: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Camera initialization failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startDateTimeUpdates() {
    _updateDateTime();
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateDateTime();
    });
  }

  void _updateDateTime() {
    if (mounted) {
      setState(
        () => _currentDateTime = DateTime.now().toString().substring(0, 19),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_isRecording &&
        !_isProcessing) {
      try {
        await _controller!.startVideoRecording();
        if (mounted) setState(() => _isRecording = true);
      } catch (e) {
        print('Error starting recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start recording: $e')),
          );
        }
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _isRecording) {
      try {
        if (mounted) {
          setState(() {
            _isProcessing = true;
            _processingStatus = 'Stopping recording...';
            _processingProgress = 0.1;
          });
        }

        XFile videoFile = await _controller!.stopVideoRecording();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _videoPath = videoFile.path;
            _processingStatus = 'Processing video with overlay...';
            _processingProgress = 0.3;
          });
        }

        String? processedVideoPath = await _processVideoWithOverlay(
          videoFile.path,
        );
        if (processedVideoPath != null) {
          if (mounted) {
            setState(() {
              _processingStatus = 'Saving to gallery...';
              _processingProgress = 0.8;
            });
          }
          await _saveVideoToGallery(processedVideoPath);
        } else {
          throw Exception('Failed to process video with overlay');
        }

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _processingStatus = '';
            _processingProgress = 0.0;
          });
        }
      } catch (e) {
        print('Error stopping recording: $e');
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
            _processingStatus = '';
            _processingProgress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop recording: $e')),
          );
        }
      }
    }
  }

  Future<String?> _processVideoWithOverlay(String inputVideoPath) async {
    try {
      final File inputFile = File(inputVideoPath);
      if (!await inputFile.exists() || await inputFile.length() == 0) {
        print('Invalid or empty video file: $inputVideoPath');
        return null;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = path.join(
        tempDir.path,
        'processed_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final String dateTime = DateTime.now()
          .toIso8601String()
          .replaceAll("T", " ")
          .split(".")
          .first;
      final String latStr =
          _currentPosition?.latitude.toStringAsFixed(6) ?? "0.000000";
      final String lngStr =
          _currentPosition?.longitude.toStringAsFixed(6) ?? "0.000000";
      final String overlayText = "Date: $dateTime\nLat: $latStr\nLng: $lngStr";

      final String overlayImagePath = await _createTextImage(overlayText);

      final String command =
          "-i '$inputVideoPath' -i '$overlayImagePath' -filter_complex \"overlay=20:20\" -c:a copy -y '$outputPath'";
      print('FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          try {
            await inputFile.delete();
            await File(overlayImagePath).delete();
          } catch (_) {}
          print('Video processing successful: $outputPath');
          return outputPath;
        }
      }

      print('Overlay processing failed');
      return null;
    } catch (e) {
      print('Error processing video: $e');
      return null;
    }
  }

  Future<String> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.transparent;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final width = textPainter.width + 20;
    final height = textPainter.height + 20;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
    textPainter.paint(canvas, const Offset(10, 10));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath = path.join(
      tempDir.path,
      'overlay_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(filePath);
    await file.writeAsBytes(pngBytes);
    return filePath;
  }

  Future<void> _testFFmpeg() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        print('FFmpeg is working correctly');
      } else {
        print('FFmpeg test failed');
      }
    } catch (e) {
      print('FFmpeg test error: $e');
    }
  }

  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      final String result = await platform.invokeMethod('saveVideoToGallery', {
        'videoPath': videoPath,
        'dateTime': _currentDateTime,
        'latitude': _currentPosition?.latitude ?? 0.0,
        'longitude': _currentPosition?.longitude ?? 0.0,
      });

      print('Video saved to gallery: $result');

      if (mounted) {
        setState(() => _processingProgress = 1.0);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video with overlay saved to gallery successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on PlatformException catch (e) {
      print('Platform exception: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('General exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    return CameraPreview(_controller!);
  }

  Widget _buildOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date/Time: $_currentDateTime',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_currentPosition != null) ...[
              Text(
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ] else
              const Text(
                'Location: Getting GPS...',
                style: TextStyle(color: Colors.yellow, fontSize: 14),
              ),
            if (_isRecording) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Recording - Overlay will be saved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    if (!_isRecording) return const SizedBox.shrink();
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              'REC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    if (!_isProcessing) return const SizedBox.shrink();
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black87,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _processingStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _processingProgress,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
              ),
              const SizedBox(height: 6),
              Text(
                '${(_processingProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera App'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildOverlay(),
          _buildRecordingIndicator(),
          _buildProcessingIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_isProcessing)
            ? null
            : (_isRecording ? _stopRecording : _startRecording),
        backgroundColor: _isProcessing
            ? Colors.grey
            : (_isRecording ? Colors.red : Colors.blue),
        elevation: 6,
        shape: const CircleBorder(),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(_isRecording ? Icons.stop : Icons.videocam, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
