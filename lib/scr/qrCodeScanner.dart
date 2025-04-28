import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/verifyTicket.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class QrCodeTab extends StatelessWidget {
  const QrCodeTab({super.key});

  Future<void> _requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      // Navigate to scanner when permission is granted
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const QRScannerPage()),
      );
    } else {
      // Show error message if permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF0A1933), // Dark blue background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            // Logo with pencil icon

            const Spacer(),
            // Scan button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              child: ElevatedButton(
                onPressed: () => _requestCameraPermission(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA50000), // Teal button color
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'TAP TO SCAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  String? scannedCode;
  bool isScanning = true;
  bool isVerifying = false;
  Map<String, dynamic>? verificationResult;
  String? errorMessage;

  // Add tracking for multiple tickets
  List<Map<String, dynamic>> scannedTickets = [];
  double totalAmount = 0.0;
  String? currentClientId;
  String? currentClientName;
  String? pinCoup;
  Set<String> scannedTokens = {};
  Set<String> scannedCouponIds = {};
  List<String> successfullyScannedCodes = [];
  List<String> scannedCouponIdsList = [];
  // New: List to track individual ticket amounts
  List<double> ticketAmounts = [];

  // Save verification result to SharedPreferences
  Future<void> _saveVerificationResult(Map<String, dynamic> result) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert the entire verification result to a JSON string
      final String resultJson = jsonEncode(result);

      // Save the result using a consistent key
      await prefs.setString('last_verification_result', resultJson);

      // Optionally, save a timestamp of when this was saved
      await prefs.setInt(
          'last_verification_timestamp', DateTime.now().millisecondsSinceEpoch);

      // For debugging - you can remove this in production
      print('Verification result saved to SharedPreferences');
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
    }
  }

  // Get the last verification result from SharedPreferences
  Future<Map<String, dynamic>?> _getLastVerificationResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? resultJson = prefs.getString('last_verification_result');

      if (resultJson != null) {
        return jsonDecode(resultJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error reading from SharedPreferences: $e');
      return null;
    }
  }

  Future<void> verifyTicket(String token) async {
    if (scannedTokens.contains(token)) {
      setState(() {
        errorMessage = 'This ticket has already been scanned';
        isVerifying = false;
      });
      return;
    }
    setState(() {
      isVerifying = true;
      errorMessage = null;
    });

    try {
      // Get the auth provider to access logged-in user data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Check if user is logged in
      if (user == null) {
        setState(() {
          errorMessage = 'User not logged in. Please log in to verify tickets.';
          isVerifying = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/Sunmi_POS_App_V2/verify_ticket'),
        body: {
          'token': token,
          'userRole': user.role.toString(),
          'userId': user.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Ticket verification response: $result');

        String? couponId = result['couponId']?.toString() ?? "";
        if (couponId.isNotEmpty && scannedCouponIds.contains(couponId)) {
          setState(() {
            errorMessage =
                'This ticket has already been scanned (duplicate coupon ID)';
            isVerifying = false;
          });
          return;
        }
        setState(() {
          verificationResult = result;
          isVerifying = false;

          // Check if this is a valid ticket
          if (result['status'] == 'not_sold') {
            successfullyScannedCodes.add(token);
            scannedTokens.add(token);
            if (couponId.isNotEmpty) {
              scannedCouponIds.add(couponId);
              scannedCouponIdsList.add(couponId);
            }

            // Check if it's the first ticket or from the same client
            String resultClientId =
                result['client']?['client_id']?.toString() ?? '';
            String resultClientName =
                result['client']?['Client_name'] ?? 'Unknown';
            String resultClientPin = result['client']?['pin'] ?? 'Unknown';
            print(" %%%%%%%%%%%%%%% $resultClientId");

            // If it's the first ticket or matches the current client
            if (currentClientId == null || currentClientId == resultClientId) {
              // Add to scanned tickets
              scannedTickets.add(result);

              // Update client info
              currentClientId = resultClientId;
              currentClientName = resultClientName;
              pinCoup = resultClientPin;

              // Update total amount and store individual amount
              double ticketAmount =
                  double.tryParse(result['ticketAmout']?.toString() ?? '0') ??
                      0;
              totalAmount += ticketAmount;

              // Add this ticket's amount to the ticketAmounts array
              ticketAmounts.add(ticketAmount);

              // Save the individual ticket verification result to SharedPreferences
              _saveVerificationResult(result);
            } else {
              // Different client error
              errorMessage =
                  'This ticket belongs to a different client. Please finalize the current transaction first.';
            }
          } else {
            // Even if the ticket is invalid or already sold, we might want to save this information
            _saveVerificationResult(result);
          }
        });
      } else {
        setState(() {
          errorMessage =
              'Verification failed. Server returned ${response.statusCode}';
          isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isVerifying = false;
      });
    }
  }

  void _resetScannerForNewTicket() {
    setState(() {
      scannedCode = null;
      isScanning = true;
      verificationResult = null;
      errorMessage = null;
      // Don't reset the scannedTickets, ticketAmounts or totalAmount
    });
  }

  void _resetAllForNewClient() {
    setState(() {
      scannedCode = null;
      isScanning = true;
      verificationResult = null;
      errorMessage = null;
      scannedTickets = [];
      scannedTokens = {}; // Clear the set of scanned tokens
      scannedCouponIds = {}; // Clear the set of scanned coupon IDs
      successfullyScannedCodes = []; // Clear the successfully scanned codes
      scannedCouponIdsList = []; // Clear the list of couponIds
      ticketAmounts = []; // Clear the ticket amounts array
      totalAmount = 0.0;
      currentClientId = null;
      currentClientName = null;
    });
  }

  void _proceedToVerification() {
    if (scannedTickets.isNotEmpty) {
      // Create a combined verification result for all scanned tickets
      final combinedResult = {
        'tickets': scannedTickets,
        'totalAmount': totalAmount,
        'clientName': currentClientName,
        'clientId': currentClientId,
        'ticketCount': scannedTickets.length,
        'pin': pinCoup,
        'scannedCodes': successfullyScannedCodes, // Add the array of codes
        'couponIds': scannedCouponIdsList, // Add the couponIds array here
        'ticketAmounts': ticketAmounts, // Add the array of ticket amounts
        'successfulScansCount': successfullyScannedCodes
            .length, // Add the count of successful scans
      };

      // Save the combined result to SharedPreferences
      _saveVerificationResult(combinedResult);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Verifyticket(
              verificationResult: combinedResult,
              scannedCode: successfullyScannedCodes,
              coupId: scannedCouponIdsList,
              ticketAmounts: ticketAmounts,
              successfulScansCount: successfullyScannedCodes
                  .length), // Pass the ticket amounts array
        ),
      ).then((_) {
        // When returning from the verification page, reset everything for a new client
        _resetAllForNewClient();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Optionally, you could load the last verification result when the page initializes
    _loadLastVerificationResult();
  }

  // Method to load last verification result
  Future<void> _loadLastVerificationResult() async {
    final lastResult = await _getLastVerificationResult();
    if (lastResult != null) {
      // You could either show this to the user or just keep it for reference
      print('Last verification result loaded from SharedPreferences');

      // If you want to display it, you could do something like:
      /*
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Previous verification data is available'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Show the saved data
            },
          ),
        ),
      );
      */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400 // Change the title text color
                )),
        backgroundColor: const Color(0xFF870813),
        // backgroundColor: const Color(0xFF0A1933),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context); // Goes back to the previous screen
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: isScanning
                ? Stack(
                    children: [
                      MobileScanner(
                        controller: controller,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty && isScanning) {
                            final String code =
                                barcodes.first.rawValue ?? 'Unknown QR Code';
                            print('==========================================');
                            print('QR CODE SCANNED:');
                            print(code);
                            print(
                                '=====!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!=====================================');
                            setState(() {
                              scannedCode = code;
                              isScanning = false;
                            });
                            // Verify the scanned ticket
                            verifyTicket(code);
                          }
                        },
                      ),
                      // Scanner overlay
                      Container(
                        decoration: ShapeDecoration(
                          shape: QrScannerOverlayShape(
                            borderColor: const Color(0xFF26C6B4),
                            borderRadius: 10,
                            borderLength: 30,
                            borderWidth: 10,
                            cutOutSize: MediaQuery.of(context).size.width * 0.8,
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    // color: const Color(0xFF0A1933),
                    child: Center(
                      child: Icon(
                        verificationResult != null
                            ? (verificationResult!['status'] == 'not_sold'
                                ? Icons.check_circle_outline
                                : Icons.error_outline)
                            : (isVerifying
                                ? Icons.hourglass_bottom
                                : Icons.error_outline),
                        size: 100,
                        color: verificationResult != null
                            ? (verificationResult!['status'] == 'not_sold'
                                ? const Color(0xFF26C6B4)
                                : const Color(0xFF870813))
                            : (isVerifying ? Colors.amber : Color(0xFF870813)),
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              // color: const Color(0xFF0A1933),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isVerifying) ...[
                      const CircularProgressIndicator(
                        color: Color(0xFF26C6B4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Verifying ticket...',
                        style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w400),
                      ),
                    ] else if (verificationResult != null) ...[
                      Text(
                        verificationResult!['status'] == 'not_sold'
                            ? 'Ticket Valid'
                            : 'Ticket Invalid',
                        style: const TextStyle(
                          // color: Colors.black54,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display multiple ticket info if we have scanned tickets
                            if (scannedTickets.isNotEmpty) ...[
                              _buildTicketDetailRow(
                                'Total Amount',
                                totalAmount.toString(),
                              ),
                              const SizedBox(height: 8),

                              // List each scanned ticket with its details
                              ...scannedTickets.asMap().entries.map((entry) {
                                int index = entry.key;
                                Map<String, dynamic> ticket = entry.value;
                                double amount = ticketAmounts[
                                    index]; // Use the stored amount from array

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ticket #${index + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFF26C6B4),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildTicketDetailRow(
                                        'Amount',
                                        amount
                                            .toString(), // Use the value from ticketAmounts array
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],

                            // Actions based on verification result
                            if (verificationResult!['status'] ==
                                'not_sold') ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Button to scan another ticket
                                  ElevatedButton(
                                    onPressed: _resetScannerForNewTicket,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                    child: const Text(
                                      'Scan Another',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  // Button to verify all scanned tickets
                                  ElevatedButton(
                                    onPressed: _proceedToVerification,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF26C6B4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                    child: const Text(
                                      'Verify All Tickets',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (verificationResult!['status'] ==
                                'checked') ...[
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildTicketDetailRow(
                                    'Status',
                                    verificationResult!['status']?.toString() ??
                                        'Unknown',
                                  ),
                                  // Button to scan again when ticket is invalid
                                  ElevatedButton(
                                    onPressed: _resetScannerForNewTicket,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF870813),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                    child: const Text(
                                      'Scan Again',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  // Existing verify ticket button
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else if (errorMessage != null) ...[
                      const Text(
                        'Verification Failed',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF870813),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            scannedCode = null;
                            isScanning = true;
                            errorMessage = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26C6B4),
                        ),
                        child: const Text(
                          'Scan Again',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ] else if (scannedCode != null) ...[
                      Text(
                        'QR Code Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Token: $scannedCode',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Text(
                        'Scanning...',
                        style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTicketDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              // color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  // color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// Custom QR scanner overlay shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 10.0,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 10.0,
    this.borderLength = 30.0,
    this.cutOutSize = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          Radius.circular(borderRadius),
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(getOuterPath(rect), paint);

    final cutOut = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw corners
    final double halfSize = cutOutSize / 2;
    final double halfBorderLength = borderLength / 2;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOut.left - borderWidth / 2, cutOut.top + halfBorderLength)
        ..lineTo(cutOut.left - borderWidth / 2, cutOut.top - borderWidth / 2)
        ..lineTo(cutOut.left + halfBorderLength, cutOut.top - borderWidth / 2),
      borderPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOut.right + borderWidth / 2, cutOut.top + halfBorderLength)
        ..lineTo(cutOut.right + borderWidth / 2, cutOut.top - borderWidth / 2)
        ..lineTo(cutOut.right - halfBorderLength, cutOut.top - borderWidth / 2),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(
            cutOut.left - borderWidth / 2, cutOut.bottom - halfBorderLength)
        ..lineTo(cutOut.left - borderWidth / 2, cutOut.bottom + borderWidth / 2)
        ..lineTo(
            cutOut.left + halfBorderLength, cutOut.bottom + borderWidth / 2),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(
            cutOut.right + borderWidth / 2, cutOut.bottom - halfBorderLength)
        ..lineTo(
            cutOut.right + borderWidth / 2, cutOut.bottom + borderWidth / 2)
        ..lineTo(
            cutOut.right - halfBorderLength, cutOut.bottom + borderWidth / 2),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
