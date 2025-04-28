import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/NFCTapCard.dart';
import 'package:ikwimpay/scr/firstScreen.dart';
import 'package:ikwimpay/scr/homescreen.dart';
import 'package:ikwimpay/scr/plateScanner.dart';
import 'package:ikwimpay/scr/status.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VerifyVehicleScreen extends StatefulWidget {
  final String cardId;

  final Map<String, dynamic> responseData;

  const VerifyVehicleScreen({
    Key? key,
    required this.cardId,
    required this.responseData,
  }) : super(key: key);

  @override
  State<VerifyVehicleScreen> createState() => _VerifyVehicleScreenState();
}

class _VerifyVehicleScreenState extends State<VerifyVehicleScreen> {
  final TextEditingController _plateNumberController = TextEditingController();
  bool _isVerifying = false;
  bool _isVehicleVerified = false;
  bool _isNfcReading = false;
  bool _isReading = false;
  bool _isStartingTransaction = false;
  String? _savedPlateNumber;
  String? _savedimagepath;
  String _nozzle_tag = '1';
  String? _nozzleID = ' ';
  // NFC-related variables
  String _nfcStatus = 'Not scanning';
  String? _nozzleIdcard;
  String? _clientname;
  String? _balance;
  Map<String, dynamic>? _verificationResult;

  String _reverseHexString(String hex) {
    List<String> hexBytes = [];
    for (var i = 0; i < hex.length; i += 2) {
      hexBytes.add(hex.substring(i, i + 2));
    }
    return hexBytes.reversed.join();
  }

  @override
  void initState() {
    super.initState();
    _mapResponseData();
  }

  void _mapResponseData() {
    _clientname =
        widget.responseData['data']?['client_name'].toString() ?? 'N/A';
    _balance = widget.responseData['data']?['balance'].toString() ?? 'N/A';
    // Optional: Print for debugging
    print('_clientnameFFFFFFFFFFF : $_clientname');
    print('_clientnameFFFFFFFFFFF : $_balance');
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlateNumber() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPlateNumber = prefs.getString('plateNumber');
    String? imagepath = prefs.getString('base64Image');

    await prefs.remove('plateNumber');

    setState(() {
      _savedimagepath = imagepath;
      _savedPlateNumber = savedPlateNumber;
      if (_savedPlateNumber != null) {
        _plateNumberController.text = _savedPlateNumber!;
      }
    });
  }

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

      await _loadSavedPlateNumber();
    } catch (e) {
      print(' Error accessing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera')),
      );
    }
  }

  Future<void> _verifyCard() async {
    try {
      Map<String, dynamic> requestBody = {
        'nozzle_tag': _nozzle_tag,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/nozzle/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      final responseData = jsonDecode(response.body);
      print("reponse Data &&&&&&&&&&&&&&&&: $responseData");
      if (responseData['status'] == 200) {
        await _startTransaction;
        print('************ ${responseData['data']['nozzle_id']}');
        _nozzleIdcard = responseData['data']['nozzle_id'].toString();

        await _saveZolle(_nozzleIdcard);
        // Optional: If you want to do something after nozzle verification
      } else {
        setState(() {
          _nfcStatus = 'Verification failed: ${responseData['message']}';
        });
        print('%%%%%%%%%%%% $responseData');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${responseData['data']}'),
            backgroundColor: const Color(0xFFA50000),
          ),
        );
      }
    } catch (e) {
      setState(() {
        print(e.toString());
      });

      ;
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _startTransaction() async {
    setState(() {
      _isStartingTransaction = true; // Set loading state
    });
    if (_verificationResult == null || _nozzleIdcard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please complete vehicle and nozzle verification first'),
          backgroundColor: const Color(0xFFA50000),
        ),
      );
      setState(() {
        _isStartingTransaction = false; // Reset loading state
      });
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      setState(() {
        _isStartingTransaction = false; // Reset loading state
      });
      return;
    }

    try {
      String userId = user.userId.toString();
      print(_verificationResult?['card_type'] == 3);
      // Prepare request body based on card type
      Map<String, dynamic> requestBody;
      print(_verificationResult?['card_type'] == 3);

      // Check if card type is 4
      if (_verificationResult?['card_type'] == 3) {
        requestBody = {
          'card_id': _verificationResult!['card_id'].toString(),
          'plate_no': _plateNumberController.text,
          'nozzle_id': _nozzleIdcard.toString(),
          'user_id': userId.toString(),
          'plate_image': _savedimagepath.toString(),
        };
      } else {
        // Original request body for other card types
        requestBody = {
          'card_id': _verificationResult!['card_id'],
          'car_id': _verificationResult!['car_id'],
          'nozzle_id': _nozzleIdcard,
          'user_id': userId,
          'plate_image': _savedimagepath.toString(),
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/transaction/command/lock'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      print('HJJJJJJJJJJJJJJJJJ ${jsonEncode(requestBody)}');
      Map<String, dynamic> responseData = jsonDecode(response.body);
      print('&&&&&&&&&&&&&&&&&&&&hhhhhhhhhhhhh ${responseData}');
      print('&&&&&&&&&&&&&&&&&&&&hhhhhhhhhhhhh $_savedimagepath');

      if ((responseData['success'] == 200) || responseData['status'] == '200') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction started successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(initialIndex: 3),
              ));
        }); // TODO: Navigate to the next screen or perform next action
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Transaction lock failed: ${responseData['message'] ?? 'Unknown error'}'),
            backgroundColor: const Color(0xFFA50000),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(initialIndex: 1),
              ));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting transaction: ${e.toString()}'),
          backgroundColor: const Color(0xFFA50000),
        ),
      );
    } finally {
      setState(() {
        _isStartingTransaction = false;
      });
    }
  }

  Future<void> _verifyVehicle() async {
    final plateNumber = _plateNumberController.text.trim();

    if (plateNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a plate number'),
          backgroundColor: Color(0xFFA50000),
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    final prefs = await SharedPreferences.getInstance();
    String? cardNumber = prefs.getString('serialDecimal');
    try {
      final storage = FlutterSecureStorage();
      String? pin = await storage.read(key: 'PIN');
      await storage.delete(key: 'PIN');

      Map<String, dynamic> requestBody = {
        'card_no': cardNumber,
        'pin': pin,
        'plate_no': plateNumber,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/card/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      print('&&&&&&&&&&&&&&&&&&&&& ${response.body}');
      Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['status'] == 200) {
        Map<String, dynamic> verificationResult = {
          'card_no': responseData['data']['card_no'] ?? 'N/A',
          'card_id': responseData['data']['card_id'] ?? 'N/A',
          'car_id': responseData['data']['car_id'] ?? 'N/A',
          'balance': responseData['data']['balance'] ?? 'N/A',
          'client_name': responseData['data']['client_name'] ?? 'N/A',
          'card_type': responseData['data']['card_type'] ?? 'N/A',
        };
        setState(() {
          _verificationResult = verificationResult;
          _isVehicleVerified = true;
        });
        print('7777777777777777 ${_verificationResult?['car_id']}');
        _startNfcNozzleScanning();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle verified successfully! Scanning nozzle...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Verification failed: ${responseData['message'] ?? 'Unknown error'}'),
            backgroundColor: const Color(0xFFA50000),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFA50000),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _saveZolle(_nozzleIdcard) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serialDecimal', _nozzleIdcard);

    print('Card ID saved to SharedPreference: $_nozzleIdcard');
  }

  Future<void> _startNfcNozzleScanning() async {
    if (_isNfcReading) return;

    setState(() {
      _isNfcReading = true;
      _isReading = true;
      _nfcStatus = 'Scanning for nozzle NFC tag...';
    });

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold your device near the nozzle NFC tag',
      );
      String serial = tag.id;
      String reversedSerial = _reverseHexString(serial);
      int? serialInt = int.tryParse(reversedSerial, radix: 16);
      String serialDecimal =
          serialInt != null ? serialInt.toString() : "Conversion failed";

      _nozzle_tag = serialDecimal;

      // Call the verification method for the nozzle
      await _verifyCard();

      setState(() {
        // _nfcStatus = 'Nozzle Detected Successfully!';
      });
      print('&&&&&&&&&&&&&&&&&&&&& ${_nozzle_tag}');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Nozzle Detected Successfully'),
      //     backgroundColor: Colors.green,
      //   ),
      // );
    } catch (e) {
      setState(() {
        print('Error scanning nozzle: ${e.toString()}');
        _nfcStatus = 'Try Gain';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Polling nozzole timeout'),
          backgroundColor: const Color(0xFFA50000),
        ),
      );
    } finally {
      await FlutterNfcKit.finish();
      if (mounted) {
        setState(() {
          _isNfcReading = false;
        });
      }
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Client',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildInfoItem('Name:', _clientname.toString()),
                      _buildInfoItem('Balance:', _balance.toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enter Vehicle Plate Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _plateNumberController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                // readOnly: false,
                enabled: !_isVehicleVerified,
                decoration: InputDecoration(
                  hintText: 'e.g., RAB123A',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  fillColor:
                      _isVehicleVerified ? Colors.grey[200] : Colors.white,
                  filled: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanLicensePlate,
                    tooltip: 'Scan plate with camera',
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (!_isVehicleVerified)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA50000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isVerifying ? 'Verifying...' : 'Verify Vehicle',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              else ...[
                Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contactless,
                        size: 100,
                        color:
                            _isReading ? const Color(0xFFA50000) : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _nfcStatus,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!_isNfcReading && _nozzleIdcard == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton(
                          onPressed: _startNfcNozzleScanning,
                          child: const Text('Scan Nozzle'),
                        ),
                      ),
                    if (_isVehicleVerified && _nozzleIdcard != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isStartingTransaction
                                ? null // Disable button when loading
                                : _startTransaction,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: _isStartingTransaction
                                  ? Colors
                                      .grey.shade400 // Disabled/loading color
                                  : const Color(0xFFA50000),
                            ),
                            child: _isStartingTransaction
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    'Start Transaction',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      )
                  ],
                ))
              ]
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildInfoItem(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 3),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
