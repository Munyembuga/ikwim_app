import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/verifyVehiche.dart';
// import 'package:ikwimpay/scr/matchCard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:/scr/VerifyVehicleScreen.dart';

class NFCScreen extends StatefulWidget {
  const NFCScreen({Key? key}) : super(key: key);

  @override
  State<NFCScreen> createState() => _NFCScreenState();
}

class _NFCScreenState extends State<NFCScreen> {
  bool _isReading = false;
  bool _isVerifying = false;
  String _nfcStatus = 'Ready to scan';
  String _nfcData = 'No data';
  String _serialDecimalValue = '1';
  String? _savedCardId;
  String? _cardnumber;
  bool _showPinInput = false;
  bool _hideStartScanButton = false;
  String? _clientName;
  bool _start = false;
  String? _card_codef;
  String? _card_type_name;
  bool _cardinfo = false;
  bool _showCardinfo = false;

  String _reverseHexString(String hex) {
    // Splits the hex string into two-character chunks and reverses the order.
    List<String> hexBytes = [];
    for (var i = 0; i < hex.length; i += 2) {
      hexBytes.add(hex.substring(i, i + 2));
    }
    return hexBytes.reversed.join();
  }

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    // _getCardInfo();
    _loadSavedCardId();
  }

  @override
  void dispose() {
    // Make sure to finish any NFC session when the screen is disposed
    _finishNfcSession();
    _textController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Load the saved card ID from SharedPreferences
  Future<void> _loadSavedCardId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedCardId = prefs.getString('cardId');
      if (_savedCardId != null) {
        _nfcStatus = 'Card ID loaded from storage';
        _nfcData = 'Saved Card ID: $_savedCardId';
        _showPinInput = true;
        _hideStartScanButton = true;
      }
    });
  }

  // Save card ID to SharedPreferences
  Future<void> _saveCardId(String serialDecimal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serialDecimal', serialDecimal);
    setState(() {
      _savedCardId = serialDecimal;
      _showPinInput = true;
      _hideStartScanButton = true;
    });
    print('Card ID saved to SharedPreferences: $serialDecimal');
  }

  // Future<void> _saveCardIdDefault(String cardIdDefault) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('cardId', cardIdDefault);
  //   setState(() {
  //     _savedCardIdDefau = cardIdDefault;
  //     _showPinInput = true;
  //     _hideStartScanButton = true;
  //   });
  //   print('Card ID saved to SharedPreferences: $cardIdDefault');
  // }

  Future<void> _checkNfcAvailability() async {
    try {
      NFCAvailability availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        setState(() {
          _nfcStatus = 'NFC not available on this device';
          _start = false;
        });

        print('NFC is not available on this device');
      } else {
        setState(() {
          _nfcStatus = 'NFC is available. Ready to scan.';
        });
        await _readNfcTag();
        _start = true;

        print('NFC is available and ready to scan');
      }
    } catch (e) {
      setState(() {
        _nfcStatus = 'Error checking NFC ';
        print('Error checking NFC:${e.toString()} ');
      });
      print('Error checking NFC: $e');
    }
  }

  Future<void> _readNfcTag() async {
    if (_isReading) return;

    setState(() {
      _isReading = true;
      _nfcStatus = 'Scanning for card...';
    });

    print('Starting NFC scan session...');

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold your device near the NFC tag',
      );

      String serial = tag.id;
      // _cardnumber = serial.toString();
      // Reverse the hex string to match electronic NFC reader's order
      String reversedSerial = _reverseHexString(serial);
      // Convert reversed hex serial to decimal if possible
      int? serialInt = int.tryParse(reversedSerial, radix: 16);
      String serialDecimal =
          serialInt != null ? serialInt.toString() : "Conversion failed";
      String identification = "Type: ${tag.type}";
      if (tag.atqa != null) identification += ", ATQA: ${tag.atqa}";
      if (tag.sak != null) identification += ", SAK: ${tag.sak}";
      _serialDecimalValue = serialDecimal;
      // setState(() {
      //   _nfcInfo =
      //       "Card Serial (Hex): $serial\nCard Serial (Dec): $serialDecimal\nIdentification: $identification";
      // });
      // Save the card ID to SharedPreferences
      await _getCardInfo();

      setState(() {
        _nfcData = serial;
        _nfcStatus = 'Card detected and saved!';
        // _showPinInput = false;
        _hideStartScanButton = true;
      });

      print('===== NFC TAG DETECTED =====');
      print('ID: ${tag.id}');
      print('Type%%%%%%%%%%%%%%%%%: ${serialDecimal}');
      print('Standard: ${tag.standard}');
      print('===========================');

      // Attempt to read NDEF data if available
      if (tag.ndefAvailable == true) {
        print('NDEF tag detected. Reading data...');
        try {
          // Read NDEF message
          var ndefRecords = await FlutterNfcKit.readNDEFRecords();

          if (ndefRecords.isNotEmpty) {
            String tagData =
                'ID: ${tag.id}\nType: ${tag.type}\nStandard: ${tag.standard}\n\n';

            for (int i = 0; i < ndefRecords.length; i++) {
              var record = ndefRecords[i];

              // Parse NDEF record
              tagData += 'Record $i:\n';
              tagData += '  Type: ${record.type}\n';

              // Handle different record types
              if (record.payload != null) {
                if (record.type == 'Text') {
                  // Parse payload for Text records - Skip language code bytes
                  String text = '';
                  try {
                    var payload = record.payload!;
                    // First byte indicates encoding and length of language code
                    int languageCodeLength = payload[0] & 0x3F;
                    // Skip language code bytes and convert to string
                    if (payload.length > languageCodeLength + 1) {
                      text = String.fromCharCodes(
                          payload.sublist(languageCodeLength + 1));
                    }
                  } catch (e) {
                    text = 'Error parsing text: $e';
                  }
                  tagData += '  Content: $text\n';
                } else {
                  // For other records, show payload as hex
                  try {
                    String hexPayload = record.payload!
                        .map((e) => e.toRadixString(16).padLeft(2, '0'))
                        .join(' ');
                    tagData += '  Payload (hex): $hexPayload\n';
                  } catch (e) {
                    tagData += '  Payload: Error parsing\n';
                  }
                }
              } else {
                tagData += '  Payload: null\n';
              }
            }

            setState(() {
              _nfcData = serial;
              _nfcStatus = 'Tag read successfully and saved!';
            });
            print('===== NFC TAG DATA =====');
            print(tagData);
            print('========================');
          } else {
            setState(() {
              _nfcData = serial;
              _nfcStatus = 'Tag detected but no readable data';
            });
            print('Tag detected but no NDEF records found');
          }
        } catch (e) {
          setState(() {
            _nfcData = ' Try gain please!';
            _nfcStatus = 'Error reading NDEF data';
          });
          print('Error reading NDEF data: $e');
        }
      }
      // await _getCardInfo();
    } catch (e) {
      setState(() {
        _nfcStatus = 'Try gain';
        print('Error: ${e.toString()}');
      });
      print('Error reading NFC tag: $e');
    } finally {
      await FlutterNfcKit.finish();
      if (mounted) {
        setState(() {
          _isReading = false;
        });
      }
      print('NFC session finished');
    }
  }

  void _finishNfcSession() {
    FlutterNfcKit.finish().catchError((e) {
      // Ignore errors when finishing the session
      print('Error finishing NFC session: $e');
    });
  }

  // Clear saved card ID and reset to initial state
  Future<void> _resetCardData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cardId');

    setState(() {
      _savedCardId = null;
      _nfcStatus = 'Ready to scan';
      _nfcData = 'No data';
      _showPinInput = false;
      _hideStartScanButton = false;
      _pinController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card data cleared'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _getCardInfo() async {
    try {
      // Use the saved card ID or the default one if available
      // String cardId = _savedCardId ?? _savedCardIdDefau ?? '';
      // String cardId = '0587210981';
      // Prepare the request body
      String cardnum = _serialDecimalValue.toString();
      Map<String, dynamic> requestBody = {
        'card_no': cardnum,
      };

      // Make the API call
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/card/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      final responseData = jsonDecode(response.body);

      if ((responseData['status'] == 200) ||
          (responseData['status'] == '200')) {
        // Parse the response
        final responseData = jsonDecode(response.body);
        print(responseData);
        _card_codef = responseData['data']['card_code'];
        _card_type_name = responseData['data']['card_type_name'];
        print(_card_codef);
        setState(() {
          _nfcStatus = 'Card is Valid!';
        });
        setState(() {
          _showPinInput = true;
          _cardinfo = true;
          _showCardinfo = true;
          _hideStartScanButton = true;
        });
        // _verifyCard();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _saveCardId(_serialDecimalValue);

        // You can navigate to another screen here if needed
      } else {
        // Handle error response
        setState(() {
          _showCardinfo = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${responseData['data']}'),
            backgroundColor: const Color(0xFFA50000),
          ),
        );
      }
    } catch (e) {
      setState(() {
        // _nfcStatus = 'Error during verification: ${e.toString()}';
        print('fffffffffffffffffff ${e.toString()}');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Error'),
          backgroundColor: const Color(0xFFA50000),
        ),
      );
    } finally {
      setState(() {
        // _isVerifying = false;
      });
    }
  }

  Future<void> _verifyCard() async {
    if (_pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your PIN'),
          backgroundColor: Color(0xFFA50000),
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _nfcStatus = 'Verifying card...';
    });

    try {
      // Use the saved card ID or the default one if available
      // String cardId = _savedCardId ?? _savedCardIdDefau ?? '';
      // String cardId = '0587210981';
      // Prepare the request body
      String cardnum = _serialDecimalValue.toString();
      Map<String, dynamic> requestBody = {
        'card_no': cardnum,
        'pin': _pinController.text,
      };

      // Make the API call
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/card/command/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      final responseData = jsonDecode(response.body);

      if ((responseData['status'] == 200) ||
          (responseData['status'] == '200')) {
        // Parse the response
        final responseData = jsonDecode(response.body);
        print(responseData);
        setState(() {
          _nfcStatus = 'Card verified successfully!';
        });

        final storage = FlutterSecureStorage();
        await storage.write(key: 'PIN', value: _pinController.text);
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VerifyVehicleScreen(
            cardId: _serialDecimalValue,
            responseData: responseData,
          ),
        ));

        // You can navigate to another screen here if needed
      } else {
        // Handle error response
        setState(() {
          print('Verification failed:${responseData['message']}');
          _nfcStatus = 'Verification failed Try Gain';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Verification failed: ${responseData['message'] ?? "Unknown error"}'),
            backgroundColor: const Color(0xFFA50000),
          ),
        );
      }
    } catch (e) {
      setState(() {
        // _nfcStatus = 'Error during verification: ${e.toString()}';
        print('fffffffffffffffffff ${e.toString()}');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Error'),
          backgroundColor: const Color(0xFFA50000),
        ),
      );
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back button

        title: const Text(
          'NFC Reader',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        ),
        backgroundColor: const Color(0xFFA50000),
        actions: [
          if (_hideStartScanButton)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetCardData,
              tooltip: 'Scan new card',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
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
                  color: _isReading
                      ? const Color(0xFFA50000)
                      : _hideStartScanButton
                          ? const Color(0xFFA50000)
                          : Colors.grey,
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
              if (_showCardinfo) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Card type : ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _cardinfo
                                  ? Text(
                                      _card_type_name.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    )
                                  : Text(
                                      ' Invalid Card Type',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    )
                            ]),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Card number : ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _cardinfo
                                  ? Text(
                                      _card_codef.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    )
                                  : Text(
                                      ' Invalid Card',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    )
                            ])
                      ],
                    ),
                  ),
                ),
              ],
              // Only show scan button if we don't have a card ID yet
              if (!_hideStartScanButton) ...[
                const SizedBox(height: 32),
                _start
                    ? ElevatedButton(
                        onPressed: _isReading ? null : _readNfcTag,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA50000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isReading ? 'Scanning...' : 'Start Scan',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : Container(
                        child: Text(''),
                      )
              ],

              // PIN input field and verify button (shown after successful scan)
              if (_showPinInput) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Card PIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Enter PIN',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        maxLength: 6,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyCard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA50000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isVerifying ? 'Verifying...' : 'Verify Card',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
