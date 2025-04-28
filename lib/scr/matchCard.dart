import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ikwimpay/scr/plateScanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class VerifyVehicleScreen extends StatefulWidget {
  final String cardId;

  const VerifyVehicleScreen({Key? key, required this.cardId}) : super(key: key);

  @override
  State<VerifyVehicleScreen> createState() => _VerifyVehicleScreenState();
}

class _VerifyVehicleScreenState extends State<VerifyVehicleScreen> {
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String _verificationResult = '';
  bool _isVerified = false;
  String? _savedPlateNumber;

  @override
  void initState() {
    super.initState();
    _loadSavedPlateNumber();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  // Load plate number from SharedPreferences if available
  Future<void> _loadSavedPlateNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPlateNumber = prefs.getString('plateNumber');
      if (_savedPlateNumber != null) {
        _plateController.text = _savedPlateNumber!;
      }
    });
  }

  // Open camera to scan license plate
  Future<void> _scanLicensePlate() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TakePictureScreen.withoutTransaction(
            camera: firstCamera,
          ),
        ),
      );

      // Reload plate number after returning from camera screen
      await _loadSavedPlateNumber();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera: $e')),
      );
    }
  }

  // Verify vehicle with API
  Future<void> _verifyVehicle() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or scan a license plate number'),
          backgroundColor: Color(0xFFA50000),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _verificationResult = '';
      _isVerified = false;
    });

    try {
      // API endpoint for verification
      final uri = Uri.parse('https://ikwim.tab.rw/api/card/command/verify');

      // Request body with card ID and plate number
      final requestBody = {
        'card_no': widget.cardId,
        'pin': _pinController.text,
        'plate_no': _plateController.text.toUpperCase(),
      };

      // Make POST request
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // Add any other required headers like authorization if needed
        },
        body: jsonEncode(requestBody),
      );

      // Parse response body (only once)
      Map<String, dynamic> responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        responseBody = {'message': 'Error parsing response'};
      }

      if (response.statusCode == 200) {
        // Handle successful verification
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        setState(() {
          _isLoading = false;
          _isVerified = true;
          _verificationResult = 'Vehicle verified successfully!';
        });

        // Navigate or perform next action after successful verification
        // You can add navigation or other logic here
      } else {
        // Handle error response
        final errorMessage = responseBody['message'] ?? 'Unknown error';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFA50000),
            duration: Duration(seconds: 3),
          ),
        );

        setState(() {
          _isLoading = false;
          _isVerified = false;
          _verificationResult = 'Verification failed: $errorMessage';
        });
      }
    } catch (e) {
      // Handle exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: const Color(0xFFA50000),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _isLoading = false;
        _verificationResult = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Vehicle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        ),
        backgroundColor: const Color(0xFFA50000),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card information section
            // Container(
            //   padding: const EdgeInsets.all(16.0),
            //   decoration: BoxDecoration(
            //     color: Colors.grey.shade100,
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(color: Colors.grey.shade300),
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       const Text(
            //         'Card Information',
            //         style: TextStyle(
            //           fontSize: 18,
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //       const SizedBox(height: 8),
            //       Text(
            //         'Card ID: ${widget.cardId}',
            //         style: const TextStyle(
            //           fontSize: 16,
            //           fontFamily: 'monospace',
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            const SizedBox(height: 20),

            // License plate input section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'License Plate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _plateController,
                    decoration: InputDecoration(
                      labelText: 'License Plate Number',
                      hintText: 'Format: ABC123D',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.directions_car),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _scanLicensePlate,
                        tooltip: 'Scan plate with camera',
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                  ),
                  TextField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'Pin',
                      hintText: 'Enter Pin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  // Center(
                  //   child: ElevatedButton.icon(
                  //     onPressed: _isLoading ? null : _scanLicensePlate,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFFA50000),
                  //       foregroundColor: Colors.white,
                  //     ),
                  //     icon: const Icon(Icons.camera_alt),
                  //     label: const Text('Scan License Plate'),
                  //   ),
                  // ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Verification button
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _verifyVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA50000),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isLoading
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(
                  _isLoading ? 'Verifying...' : 'Verify Vehicle',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
