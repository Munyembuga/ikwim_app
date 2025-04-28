import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class ImageQRScannerPage extends StatefulWidget {
  @override
  _ImageQRScannerPageState createState() => _ImageQRScannerPageState();
}

class _ImageQRScannerPageState extends State<ImageQRScannerPage> {
  File? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  List<String> _detectedQRCodes = [];
  List<String> _additionalTextContents = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _captureImage(); // Automatically open the camera
    });
  }

  // Convert image to base64
  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  // Image capture methods
  Future<void> _captureImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() {
          _imageFile = imageFile;
        });

        // Convert image to base64
        String? base64Image = await _convertImageToBase64(imageFile);
        if (base64Image != null) {
          setState(() {
            _base64Image = base64Image;
          });
        }

        await _processImage();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture image');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() {
          _imageFile = imageFile;
        });

        // Convert image to base64
        String? base64Image = await _convertImageToBase64(imageFile);
        if (base64Image != null) {
          setState(() {
            _base64Image = base64Image;
          });
        }

        await _processImage();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image');
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final barcodes = await _barcodeScanner.processImage(inputImage);
      final qrCodeContents = barcodes
          .where((barcode) => barcode.type == BarcodeType.text)
          .map((barcode) => barcode.rawValue ?? '')
          .toList();

      if (qrCodeContents.isEmpty) {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        final textBasedQRCodes = recognizedText.blocks
            .map((block) => block.text)
            .where((text) => _isValidQRCodeFormat(text))
            .toList();

        setState(() {
          _detectedQRCodes = textBasedQRCodes;
          _additionalTextContents = textBasedQRCodes;
        });
      } else {
        setState(() {
          _detectedQRCodes = qrCodeContents;
          _additionalTextContents = [];
        });
      }

      // Handle the result based on number of QR codes detected
      _handleQRCodeResult();
    } catch (e) {
      _showErrorSnackBar('Failed to process image');
      print('Image processing error: $e');
    }
  }

  void _handleQRCodeResult() {
    if (_detectedQRCodes.length >= 2) {
      // Two QR codes detected
      if (_areQRCodesSame()) {
        // If QR codes are the same, pop and return the first QR code and base64 image
        print('DDDDDDDDDDDDDDDDDDDDD ${_detectedQRCodes}');
        Navigator.of(context)
            .pop({'qrCode': _detectedQRCodes[0], 'base64Image': _base64Image});
      } else {
        // If QR codes are different, show options to try again
        _showTryAgainDialog('QR Codes Do Not Match');
      }
    } else if (_detectedQRCodes.length == 1) {
      // Only one QR code detected
      _showTryAgainDialog('QR Codes Do Not Match');
      // Navigator.of(context)
      //     .pop({'qrCode': _detectedQRCodes[0], 'base64Image': _base64Image});
    }
  }

  void _showTryAgainDialog(String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text('Would you like to try scanning again?'),
          actions: <Widget>[
            TextButton(
              child: Text('Camera'),
              onPressed: () {
                Navigator.of(context).pop();
                _captureImage();
              },
            ),
            TextButton(
              child: Text('Gallery'),
              onPressed: () {
                Navigator.of(context).pop();
                _pickImageFromGallery();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to check if QR Code 1 and QR Code 2 are the same
  bool _areQRCodesSame() {
    if (_detectedQRCodes.length >= 2) {
      return _detectedQRCodes[0] == _detectedQRCodes[1];
    }
    return false;
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isValidQRCodeFormat(String text) {
    return text.isNotEmpty && text.length > 5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image QR Code Scanner'),
      ),
      body: Column(
        children: [
          if (_imageFile != null)
            Expanded(
              flex: 3,
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          Expanded(
            flex: 2,
            child: ListView(
              children: [
                if (_detectedQRCodes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Detected QR Codes:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...List.generate(
                    _detectedQRCodes.length,
                    (index) => ListTile(
                      title: Text('QR Code ${index + 1}'),
                      subtitle: Text(_detectedQRCodes[index]),
                    ),
                  ),

                  // Check if QR Code 1 and QR Code 2 are the same
                  if (_detectedQRCodes.length >= 2)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _areQRCodesSame()
                            ? 'QR Codes are the SAME'
                            : 'QR Codes are DIFFERENT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _areQRCodesSame() ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                ],
                if (_additionalTextContents.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Additional Text Contents:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...List.generate(
                    _additionalTextContents.length,
                    (index) => ListTile(
                      title: Text('Text ${index + 1}'),
                      subtitle: Text(_additionalTextContents[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }
}
