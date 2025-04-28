import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TakePictureScreenFrame extends StatefulWidget {
  final CameraDescription camera;
  final Map<String, dynamic>? transactionData;

  const TakePictureScreenFrame({
    super.key,
    required this.camera,
    this.transactionData,
  });

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreenFrame> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final RegExp _plateRegex = RegExp(r'[A-Z]{3}\d{3}[A-Z]{1}');

  bool _isProcessing = false;
  bool _isFlashOn = false;

  List<String> _detectedQRCodes = [];
  List<String> _detectedPlates = [];
  String? _base64Image;
  String? _imagePath;

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
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    try {
      if (_isFlashOn) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling flash: $e')),
      );
    }
  }

  Future<String?> _convertImageToBase64(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  Future<void> _takePicture(BuildContext context) async {
    setState(() {
      _isProcessing = true;
      _detectedQRCodes.clear();
      _detectedPlates.clear();
      _base64Image = null;
      _imagePath = null;
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      _imagePath = image.path;

      if (!context.mounted) return;

      // Process the image
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
      // Convert image to base64
      final base64Image = await _convertImageToBase64(imagePath);
      if (base64Image != null) {
        setState(() {
          _base64Image = base64Image;
        });
      }

      final inputImage = InputImage.fromFilePath(imagePath);

      // Scan for barcodes
      final barcodes = await _barcodeScanner.processImage(inputImage);
      final qrCodeContents =
          barcodes.map((barcode) => barcode.rawValue ?? '').toList();

      // Recognize text
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Detect license plates
      List<String> detectedPlates = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final text = line.text.replaceAll(' ', '').toUpperCase();
          final matches = _plateRegex.allMatches(text);

          for (Match match in matches) {
            final plate = match.group(0);
            if (plate != null && plate.isNotEmpty) {
              detectedPlates.add(plate);
            }
          }
        }
      }

      setState(() {
        _detectedQRCodes = qrCodeContents;
        _detectedPlates = detectedPlates;
      });

      // Handle the results
      await _handleScanResults(context, imagePath);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  Future<void> _handleScanResults(
      BuildContext context, String imagePath) async {
    // First check if we have any QR codes at all
    if (_detectedQRCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid QR code detected. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    // Check if we have multiple QR codes and they don't match
    if (_detectedQRCodes.length >= 2 && !_areQRCodesSame()) {
      _showTryAgainDialog('QR Codes Do Not Match');
      return;
    }

    // Print QR code value to terminal as requested
    print('Detected QR Code: ${_detectedQRCodes.first}');
    print('Base64 Image Length: ${_base64Image?.length ?? 'null'}');

    // Save data and navigate
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create updated transaction data
      final updatedData =
          Map<String, dynamic>.from(widget.transactionData ?? {});

      // Add plate number if detected
      if (_detectedPlates.isNotEmpty) {
        await prefs.setString('plateNumber', _detectedPlates.first);
        updatedData['plate_no'] = _detectedPlates.first;
      }

      // Add QR code if detected
      await prefs.setString('qrCode', _detectedQRCodes.first);
      updatedData['qr_code'] = _detectedQRCodes.first;

      updatedData['imagePath'] = imagePath;
      updatedData['base64Image'] = _base64Image;

      if (!context.mounted) return;

      // Print to terminal again when navigating when QR codes are the same
      if (_detectedQRCodes.length >= 2 && _areQRCodesSame()) {
        print('QR codes are identical. Value: ${_detectedQRCodes.first}');
      }

      // Navigate back with the data - we've verified QR codes are same or there's only one
      Navigator.of(context).pop({
        'qrCode': _detectedQRCodes.first,
        'base64Image': _base64Image,
        'imagePath': imagePath
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (!context.mounted) return;
      print('################## $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  bool _areQRCodesSame() {
    if (_detectedQRCodes.length >= 2) {
      print('First QR Code: ${_detectedQRCodes[0]}');
      print('Second QR Code: ${_detectedQRCodes[1]}');
      return _detectedQRCodes[0] == _detectedQRCodes[1];
    }
    return false;
  }

  void _showTryAgainDialog(String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: const Text('Would you like to try scanning again?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isProcessing = false;
                });
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close the camera screen
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA50000),
        title: const Text(
          'Scan  QR Code',
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
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.black54,
                      width: double.infinity,
                      child: const Text(
                        'Position QR code in the frame and take a picture',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Flash toggle button
                Positioned(
                  left: 20,
                  top: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ),
                ),
                // Detection results overlay
                if (_detectedPlates.isNotEmpty || _detectedQRCodes.isNotEmpty)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (_detectedQRCodes.isNotEmpty)
                            Text(
                              'Detected QR Processing',
                              style: const TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
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
                            'Processing image...',
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
