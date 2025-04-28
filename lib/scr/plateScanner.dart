import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ikwimpay/scr/completeTranscation.dart'; // Import your transaction form

// Screen to capture pictures
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final Map<String, dynamic>? transactionData;

  const TakePictureScreen({
    super.key,
    required this.camera,
    this.transactionData,
  });
  const TakePictureScreen.withoutTransaction({
    super.key,
    required this.camera,
  }) : transactionData = null;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final RegExp _plateRegex = RegExp(r'[A-Z]{3}\d{3}[A-Z]{1}');
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // Convert image file to base64 string
  Future<String> _convertImageToBase64(String imagePath) async {
    final File imageFile = File(imagePath);
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  Future<void> _takePicture(BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      if (!context.mounted) return;

      // Process the image directly
      await _processImage(image.path, context);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _processImage(String imagePath, BuildContext context) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Look for plate number pattern in recognized text
      String detectedPlate = '';

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final text = line.text.replaceAll(' ', '').toUpperCase();
          final matches = _plateRegex.allMatches(text);

          for (Match match in matches) {
            detectedPlate = match.group(0) ?? '';
            if (detectedPlate.isNotEmpty) break;
          }

          if (detectedPlate.isNotEmpty) break;
        }
        if (detectedPlate.isNotEmpty) break;
      }

      if (!context.mounted) return;

      if (detectedPlate.isNotEmpty) {
        // Valid plate detected, save and navigate
        await _savePlateAndNavigate(context, detectedPlate, imagePath);
      } else {
        // No plate detected, show error and stay on camera screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid license plate detected. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  Future<void> _savePlateAndNavigate(
      BuildContext context, String plateNumber, String imagePath) async {
    try {
      // Convert image to base64
      final String base64Image = await _convertImageToBase64(imagePath);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plateNumber', plateNumber);
      await prefs.setString('base64Image', base64Image);

      // Create updated transaction data
      final updatedData =
          Map<String, dynamic>.from(widget.transactionData ?? {});
      updatedData['plate_no'] = plateNumber;
      updatedData['imagePath'] = imagePath;
      updatedData['base64Image'] = base64Image;

      if (!context.mounted) return;

      // Navigate to transaction form screen
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA50000),
        title: const Text(
          'Scan License Plate',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CameraPreview(_controller),
                          // Overlay to guide the license plate placement
                          Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.black54,
                      width: double.infinity,
                      child: const Text(
                        'Position the license plate in the frame and take a picture\nFormat: ABC123D',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Loading overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 20),
                          Text(
                            'Processing license plate...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: _isProcessing
          ? null
          : FloatingActionButton(
              onPressed: () => _takePicture(context),
              backgroundColor: const Color(0xFFA50000),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
