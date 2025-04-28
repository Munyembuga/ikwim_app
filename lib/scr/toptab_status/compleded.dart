import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';

class CompletedTab extends StatefulWidget {
  const CompletedTab({Key? key}) : super(key: key);

  @override
  State<CompletedTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends State<CompletedTab> {
  List<Map<String, dynamic>> pendingTransactions = [];
  bool isLoading = true;
  String errorMessage = '';

  // Bluetooth printer properties
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  bool _isSelectingPrinter = false;
  bool _isSunmiAvailable = false;

  @override
  void initState() {
    super.initState();
    fetchCompletedTransactions();
    _checkSunmiPrinterAvailability();
  }

  // Check if Sunmi printer is available
  Future<void> _checkSunmiPrinterAvailability() async {
    try {
      // Handle the nullable bool? return type with null-safety
      bool? printerResult = await SunmiPrinter.bindingPrinter();

      // Set _isSunmiAvailable to false if printerResult is null
      setState(() {
        _isSunmiAvailable = printerResult ?? false;
      });

      if (printerResult == true) {
        print('Sunmi printer found');
      } else {
        print('Sunmi printer not found, will use Bluetooth printer if needed');
      }
    } catch (e) {
      print('Error checking Sunmi printer: $e');
      setState(() {
        _isSunmiAvailable = false;
      });
    }
  }

  // Initialize the Bluetooth printer
  Future<void> initBluetooth() async {
    try {
      // Request necessary permissions
      await requestPermissions();

      // Check if device is already connected
      bool isConnected = await bluetooth.isConnected ?? false;

      List<BluetoothDevice> devices = [];
      try {
        devices = await bluetooth.getBondedDevices();
      } on Exception catch (e) {
        print('Error getting bonded devices: $e');
      }

      if (!mounted) return;
      setState(() {
        _devices = devices;
      });

      if (isConnected) {
        setState(() {
          _connected = true;
        });
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  Future<void> requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.location.request();
  }

  // Connect to selected Bluetooth device
  Future<void> connectPrinter() async {
    if (_device == null) {
      _showMessage('No printer selected. Please select a printer first.');
      return;
    }

    try {
      bluetooth.isConnected.then((isConnected) {
        if (isConnected == false) {
          bluetooth.connect(_device!).catchError((error) {
            _showMessage('Error connecting to printer: $error');
            setState(() => _connected = false);
          });
          setState(() => _connected = true);
          _showMessage('Connected to ${_device!.name}');
        } else {
          _showMessage('Already connected to ${_device!.name}');
        }
      });
    } catch (e) {
      _showMessage('Error connecting to printer: $e');
    }
  }

  // Disconnect from Bluetooth device
  void disconnectPrinter() {
    try {
      bluetooth.disconnect();
      setState(() => _connected = false);
      _showMessage('Disconnected from printer');
    } catch (e) {
      _showMessage('Error disconnecting from printer: $e');
    }
  }

  // Main print function that decides which printer to use
  Future<void> printTransaction(Map<String, dynamic> transaction) async {
    try {
      // Try Sunmi printer first if available
      if (_isSunmiAvailable) {
        await _printWithSunmi(transaction);
      } else {
        // Fall back to Bluetooth printer
        await _printWithBluetooth(transaction);
      }
    } catch (e) {
      _showMessage('Error printing receipt: $e');
    }
  }

  // Print using Sunmi printer
  Future<void> _printWithSunmi(Map<String, dynamic> transaction) async {
    setState(() {
      // You can add loading state here if needed
    });

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.printText("${transaction['company_name']}",
          style: SunmiTextStyle(
              bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.printText("--------------------------------");
      await SunmiPrinter.printText("${transaction['po_box']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Telephone: ${transaction['phone']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("TIN/VAT:   101968859",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Email: ${transaction['email']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(30); // Add one line of space

      await SunmiPrinter.printText("Time: ${transaction['updatedAt']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Site: ${transaction['site_name']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Served by: ${transaction['user']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.lineWrap(30); // Add one line of space

      await SunmiPrinter.printText(
          "\n\nCustomer names: ${transaction['client_name'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(10); // Add one line of space

      await SunmiPrinter.printText("Product: ${transaction['item'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Amount: ${transaction['formatted_amount'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Unit price: ${transaction['unit_price'] ?? '1647'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Quantity: ${transaction['quantity'] ?? '0'} L",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Plate Number: ${transaction['plate_no'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Card type: ${transaction['card_type_name']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Smart card: ${transaction['card_number'] ?? 'Unknown'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.printText("--------------COPY-------------");
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("\nYour full satisfaction is our mission ",
          style: SunmiTextStyle(
            align: SunmiPrintAlign.CENTER,
          ));

      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.cutPaper();

      _showMessage('Receipt printed successfully using Sunmi printer');

      // Return to the previous screen after printing
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      _showMessage('Sunmi print error: ${e.toString()}');
      // If Sunmi printing fails, try Bluetooth as fallback
      await _printWithBluetooth(transaction);
    }
  }

  // Print using Bluetooth thermal printer
  Future<void> _printWithBluetooth(Map<String, dynamic> transaction) async {
    // Check if connected to printer
    bool isConnected = await bluetooth.isConnected ?? false;
    if (!isConnected) {
      // Show printer selection dialog if not connected
      await _selectPrinterDialog();
      isConnected = await bluetooth.isConnected ?? false;
      if (!isConnected) {
        _showMessage(
            'Printer not connected. Please connect to a printer first.');
        return;
      }
    }

    try {
      // Set text size for header
      bluetooth.printCustom(
          "${transaction['company_name']}", 2, 1); // Size 2, Centered
      bluetooth.printNewLine();
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom(
          "${transaction['po_box']}", 1, 0); // Size 1, Left-aligned
      bluetooth.printNewLine();

      bluetooth.printCustom("Telephone:${transaction['phone']}", 1, 0);
      bluetooth.printCustom("TIN/VAT:101968859", 1, 0);
      bluetooth.printCustom("Email:${transaction['email']}", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      bluetooth.printCustom("Time:${transaction['updatedAt']}", 1, 0);
      bluetooth.printCustom("Site:${transaction['site_name']}", 1, 0);
      bluetooth.printCustom("Served by:${transaction['user']}", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      bluetooth.printCustom(
          "Customer names: ${transaction['client_name'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom("Product: ${transaction['item'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Amount: ${transaction['formatted_amount'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Unit price: ${transaction['unit_price'] ?? '1647'}", 1, 0);
      bluetooth.printCustom(
          "Quantity: ${transaction['quantity'] ?? '0'} L", 1, 0);
      bluetooth.printCustom(
          "Plate Number: ${transaction['plate_no'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Card type: ${transaction['card_type_name']}", 1, 0);
      bluetooth.printCustom(
          "Smart card: ${transaction['card_number'] ?? 'Unknown'}", 1, 0);
      bluetooth.printNewLine();

      bluetooth.printCustom("--------------COPY-------------", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Your full satisfaction is our mission", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      _showMessage('Receipt printed successfully using Bluetooth printer');

      // Return to the previous screen after printing
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      _showMessage('Bluetooth print error: $e');
    }
  }

  // Show printer selection dialog
  Future<void> _selectPrinterDialog() async {
    if (_isSelectingPrinter) return;

    setState(() {
      _isSelectingPrinter = true;
    });

    // Initialize Bluetooth and get devices
    await initBluetooth();

    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Select Printer'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  if (_devices.isEmpty)
                    Text(
                        'No paired Bluetooth devices found. Please pair a printer first.'),
                  for (var device in _devices)
                    ListTile(
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.address ?? ''),
                      onTap: () {
                        this.setState(() {
                          _device = device;
                        });
                        Navigator.pop(context);
                        connectPrinter();
                      },
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Refresh'),
                onPressed: () async {
                  await initBluetooth();
                  setState(() {});
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
        });
      },
    ).then((_) {
      setState(() {
        _isSelectingPrinter = false;
      });
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showTransactionDetails(Map<String, dynamic> transaction) {
    // Get the image path from the transaction data or use a default
    final String imagePath = transaction['tr_image'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Transaction Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Divider(),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transaction Image with hover functionality
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  // Show full-size image when tapped
                                  _showFullSizeImage(context, imagePath);
                                },
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Image.network(
                                      imagePath,
                                      height: 120,
                                      width: 120,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Image.asset(
                                          '',
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              height: 120,
                                              width: 120,
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 40,
                                                color: Colors.grey[500],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: 120,
                                          width: 120,
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Divider(),
                        _buildDetailItem(
                            'Date', transaction['updatedAt'] ?? 'Unknown'),
                        _buildDetailItem(
                            'Customer', transaction['client_name']),
                        _buildDetailItem(
                            'Plate Number', transaction['plate_no'] ?? 'N/A'),
                        _buildDetailItem(
                            'Product', transaction['item'] ?? 'N/A'),
                        _buildDetailItem(
                            'Unit price', transaction['unit_price'] ?? 'N/A'),
                        _buildDetailItem('Amount',
                            transaction['formatted_amount'] ?? 'Unknown'),
                        _buildDetailItem(
                            'Quantity', '${transaction['quantity'] ?? '0'} L'),
                        _buildDetailItem(
                            'Card Type', '${transaction['card_type_name']}'),

                        _buildDetailItem(
                            'Card number', '${transaction['card_number']}'),
                        _buildDetailItem('Served by', transaction['user']),

                        if (transaction['payment_method'] != null)
                          _buildDetailItem(
                              'Payment Method', transaction['payment_method']),
                        if (transaction['location'] != null)
                          _buildDetailItem('Location', transaction['location']),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Print Receipt'),
                      onPressed: () {
                        printTransaction(transaction);
                      },
                    ),
                    TextButton(
                      child: Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Function to show full-size image
  void _showFullSizeImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Image with interactive viewer for zooming and panning
              InteractiveViewer(
                panEnabled: true,
                boundaryMargin: EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        width: 300,
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.grey[500],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        width: 300,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  iconSize: 30,
                  padding: EdgeInsets.all(10),
                  constraints: BoxConstraints(),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.black.withOpacity(0.5),
                    ),
                    shape: MaterialStateProperty.all(
                      CircleBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget for detail dialog items
  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label text with fixed width to align all values properly
              Container(
                width: 120, // Adjust width as needed for your labels
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Value text that can expand to use remaining width
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Function to check if the transaction is older than 48 hours
  bool isOlderThan48Hours(String dateString) {
    try {
      // Parse the date string from transaction
      DateTime transactionDate = DateTime.parse(dateString);

      // Get current time
      DateTime now = DateTime.now();

      // Calculate difference in hours
      Duration difference = now.difference(transactionDate);

      // Return true if older than 48 hours
      return difference.inHours >= 4000;
    } catch (e) {
      // If there's an error parsing the date, return false to be safe
      print('Error parsing date: $e');
      return false;
    }
  }

  Future<void> fetchCompletedTransactions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      setState(() {
        errorMessage = 'User not logged in. Please log in to verify tickets.';
      });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/transaction/command/get'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user.userId.toString()}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == 200 && responseData['data'] != null) {
          // Filter out transactions older than 48 hours
          List<Map<String, dynamic>> allTransactions =
              List<Map<String, dynamic>>.from(responseData['data']);

          List<Map<String, dynamic>> filteredTransactions = allTransactions
              .where((transaction) =>
                  !isOlderThan48Hours(transaction['updatedAt'] ?? ''))
              .toList();

          setState(() {
            pendingTransactions = filteredTransactions;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'No Completed transactions found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
          child: Text(errorMessage,
              style: const TextStyle(
                color: const Color(0xFFA50000),
              )));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: pendingTransactions.isEmpty
          ? const Center(
              child: Text(
                'No Completed transactions',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchCompletedTransactions,
              child: ListView.builder(
                itemCount: pendingTransactions.length,
                itemBuilder: (context, index) {
                  final item = pendingTransactions[index];
                  return _buildStatusCard(item, context);
                },
              ),
            ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> item, BuildContext context) {
    final String quantity = item['quantity'] ?? '';
    final String items = item['item'];
    final String plateNo = item['plate_no'] ?? 'Unknown';
    final String formatted_amount = item['formatted_amount'] ?? 'Unknown';
    final String date = item['updatedAt'] ?? 'Unknown';
    final String client = item['client_name'] ?? 'Unknown';
    final String cardnumber = item['card_type_name'];
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () => showTransactionDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction completed indicator
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Text(
                    date,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Divider(),
              // Two-column layout for data
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoItem('Client name:', client),
                        const SizedBox(height: 5),
                        _buildInfoItem('Plate No:', plateNo),
                        const SizedBox(height: 5),
                        _buildInfoItem('Card type:', cardnumber),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoItem('Amount:', formatted_amount),
                        const SizedBox(height: 5),
                        _buildInfoItem('Quantity:', '${quantity.toString()} L'),
                        const SizedBox(height: 5),
                        _buildInfoItem('Item:', items),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Add a print button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
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
}
