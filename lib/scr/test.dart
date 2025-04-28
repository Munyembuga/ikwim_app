import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

// void main() {
//   // Start the app
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false, // Hide the debug banner
//       home: NfcScreen(), // Set the home screen to BitCoinTracker
//     );
//   }
// }

// Main class for the NFC screen
class NfcScreen extends StatefulWidget {
  @override
  _NfcScreenState createState() => _NfcScreenState();
}

// State class for the NFC screen
class _NfcScreenState extends State<NfcScreen> {
  // Variable to store NFC data
  String _nfcData = 'No data';

  // Controller for text input
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Check if NFC is available
    NfcManager.instance.isAvailable().then((isAvailable) {
      if (isAvailable) {
        // Start NFC session if available
      } else {
        setState(() {
          // Update UI if NFC is not available
          _nfcData = 'NFC is not available';
        });
      }
    });
  }

  // Function to start NFC session
  void _writeNfcTag() {
    // Start NFC session
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      // Example of writing data to the tag
      Ndef? ndef = Ndef.from(tag);

      if (ndef != null && ndef.isWritable) {
        // Create NDEF message with input text
        NdefMessage message = NdefMessage([
          NdefRecord.createText(_textController.text),
        ]);
        try {
          // Write message to tag
          await ndef.write(message);
          setState(() {
            // Update UI on success
            _nfcData = 'Write successful!';
          });
        } catch (e) {
          setState(() {
            // Update UI on failure
            _nfcData = 'Write failed: $e';
          });
        }
      }

      // Stop NFC session
      NfcManager.instance.stopSession();
    });
  }

  // Function to read NFC tag
  void _readNfcTag() {
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      Ndef? ndef = Ndef.from(tag);
      if (ndef != null) {
        // Read message from tag
        NdefMessage? message = await ndef.read();

        setState(() {
          // Store payload in temp variable
          var rawData = message.records.first.payload;

          // Convert payload to string
          String textData = String.fromCharCodes(rawData);

          // Update UI with read data
          _nfcData = textData.substring(3);
        });
      }

      // Stop NFC session
      NfcManager.instance.stopSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Screen'), // App bar title
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Enter data to write', // Input field label
              ),
            ),
            ElevatedButton(
              onPressed: _writeNfcTag,
              child: Text('Write to NFC'), // Button to write to NFC
            ),
            ElevatedButton(
              onPressed: _readNfcTag,
              child: Text('Read from NFC'), // Button to read from NFC
            ),
            SizedBox(height: 20),
            Text(_nfcData), // Display NFC data
          ],
        ),
      ),
    );
  }
}
