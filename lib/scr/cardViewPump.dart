import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DetailedCardView extends StatefulWidget {
  final int pumpId;

  const DetailedCardView({
    Key? key,
    required this.pumpId,
  }) : super(key: key);

  @override
  _DetailedCardViewState createState() => _DetailedCardViewState();
}

class _DetailedCardViewState extends State<DetailedCardView> {
  bool _isNfcReading = false;
  bool _isReading = false;
  String _nfcStatus = '';
  String _nozzle_tag = '';
  String _nozzleIds = '';

  bool isLoading = false;
  bool isSwapping = false;

  List<dynamic> nozzle = [];
  @override
  void initState() {
    super.initState();
    fetchNozzles();
  }

  Future<void> _nozzleSwapp() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/nozzle/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nozzle_id': _nozzleIds,
          'nozzle_code': _nozzle_tag,
        }),
      );
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // nozzle = data['nozzles'];
          print("&&&&&&&&&&&&&&&&&&& $data['data]");
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle exception
      print('Error Swapp n nozzles: $e');
      setState(() {
        // isLoading = false;
      });
    }
    await Future.delayed(Duration(milliseconds: 500));
    return;
  }

// Handle submission of the nozzle tag
  void _handleSubmit() async {
    if (_nozzle_tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a nozzle tag'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      isSwapping = true; // Show loading indicator
    });

    // Call the nozzle swap function
    await _nozzleSwapp();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nozzle code updated successfully'),
        backgroundColor: const Color(0xFFA50000),
      ),
    );

    // Clear the nozzle tag after submission
    setState(() {
      _nozzle_tag = '';
      isSwapping = false; // Hide loading indicator
    });
  }

  Future<void> fetchNozzles() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role;
    final userSite = authProvider.user?.siteId;
    // Check if user has role 5

    setState(() {
      isLoading = true;
    });

    try {
      // Make the API call
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/pump/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'site': userSite,
          'pump': widget.pumpId,
        }),
      );
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nozzle = data['nozzles'];
          print("&&&&&&&&&&&&&&&&&&& $data['data]");
          isLoading = false;
        });
      } else {
        // Handle error
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle exception
      print('Error fetching nozzles: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pump Details',
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 24),
                  isLoading
                      ? Center(child: CircularProgressIndicator())
                      : nozzle.isEmpty
                          ? Text("No Nozzle found")
                          : Column(
                              children: nozzle.map<Widget>((item) {
                                return _buildPumpCard(item);
                              }).toList(),
                            ),
                ],
              ),
            ),
          ),

          // NFC scanning overlay
          if (_isNfcReading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          _nfcStatus,
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isNfcReading = false;
                            });
                            FlutterNfcKit.finish();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA50000),
                            // Button background color
                            foregroundColor: Colors.white, // Text/icon color
                            minimumSize: Size(100, 40), // Width and height
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  8), // Optional: rounded corners
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Submit button when NFC scan is successful
          if (_nozzle_tag.isNotEmpty && !_isNfcReading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 20),
                        Text(
                          _nfcStatus,
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA50000),
// Button background color
                            foregroundColor: Colors.white, // Text/icon color
                            minimumSize: Size(200, 50), // Width and height
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  8), // Optional: rounded corners
                            ),
                          ),
                          onPressed: isSwapping
                              ? null
                              : _handleSubmit, // Disable button while loading
                          child: isSwapping
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : Text('Submit',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPumpCard(Map<String, dynamic> nozzleData) {
    final nozzleName = nozzleData['nozzle_name'] ?? 'Unknown Nozzle';
    final nozzleId = nozzleData['nozzle_id']?.toString() ?? 'N/A';
    final product = nozzleData['product'] ?? 'Unknown product';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      // child: InkWell(
      // onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem('Nozzle Name: ', nozzleName, false),
                  SizedBox(height: 8),
                  _buildInfoItem('Product: ', product, false),
                ],
              ),
            ),
            // Edit icon that triggers NFC scanning
            GestureDetector(
              onTap: () {
                // Start NFC scanning when edit icon is clicked
                _startNfcNozzleScanning(nozzleId);
              },
              child: Icon(Icons.edit, color: Colors.green, size: 16),
            ),
            SizedBox(
              width: 10,
            )
          ],
        ),
      ),
    );
    // );
  }

  Widget _buildInfoItem(String label, String value, bool showEditIcon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _startNfcNozzleScanning(String nozzleId) async {
    if (_isNfcReading) return;

    setState(() {
      _isNfcReading = true;
      _isReading = true;
      _nfcStatus = 'Scanning for nozzle NFC tag...';
      _nozzle_tag = ''; // Clear previous tag data
      _nozzleIds = nozzleId; // Store the nozzle ID that was passed
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

      // Save the tag
      _nozzle_tag = serialDecimal;

      setState(() {
        _nfcStatus = 'Nozzle Detected Successfully!';
      });
      print('&&&&&&&&&&&&&&&&&&&&& $_nozzle_tag');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nozzle Detected Successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        print('Error scanning nozzle: ${e.toString()}');
        _nfcStatus = 'Try Again';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Polling nozzle timeout'),
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

  // Helper method to reverse hex string
  String _reverseHexString(String hexString) {
    List<String> pairs = [];
    for (int i = 0; i < hexString.length; i += 2) {
      if (i + 2 <= hexString.length) {
        pairs.add(hexString.substring(i, i + 2));
      } else if (i + 1 <= hexString.length) {
        pairs.add(hexString.substring(i, i + 1) + '0');
      }
    }
    return pairs.reversed.join();
  }
}
