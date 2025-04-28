import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

class BoTab extends StatefulWidget {
  const BoTab({Key? key}) : super(key: key);

  @override
  State<BoTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends State<BoTab> {
  List<Map<String, dynamic>> pendingTransactions = [];
  bool isLoading = true;
  String errorMessage = '';

  // Bluetooth printer properties
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  bool _isSelectingPrinter = false;

  // Sunmi printer availability flag
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

  // Initialize Bluetooth
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

  // Request permissions for Bluetooth
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
  Future<void> _printTransaction(Map<String, dynamic> transaction) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Try Sunmi printer first if available
      if (_isSunmiAvailable) {
        await _printWithSunmi(transaction, user);
      } else {
        // Fall back to Bluetooth printer
        await _printWithBluetooth(transaction, user);
      }
    } catch (e) {
      _showMessage('Error printing receipt: $e');
    }
  }

  // Print using Sunmi printer
  Future<void> _printWithSunmi(
      Map<String, dynamic> transaction, dynamic user) async {
    final company = user?.companyname;
    final address = user?.address;
    final phone = user.phone;

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.printText("$company ",
          style: SunmiTextStyle(
              bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.printText("--------------------------------");
      await SunmiPrinter.printText("$address",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Telephone: $phone",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("TIN/VAT:   101968859",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Email: info@ikwim.com",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(30); // Add one line of space

      await SunmiPrinter.printText("Time: ${transaction['time']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Site: ${transaction['site_name']}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Served by: ${transaction['l_name']} ${transaction['f_name']}",
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

      await SunmiPrinter.printText(
          "Product: ${transaction['product'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Consumed amount: ${transaction['consumed_amount'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Unit price: ${transaction['s_price'] ?? '1647'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Quantity: ${transaction['qty'] ?? '0'} L",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          "Balance amount: ${transaction['balance'] ?? '0'} L",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7);

      await SunmiPrinter.printText(
          "Plate Number: ${transaction['plate_no'] ?? 'N/A'}",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Type: Bon",
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("Ref ${transaction['ref'] ?? 'Unknown'}",
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
      await _printWithBluetooth(transaction, user);
    }
  }

  // Print using Bluetooth thermal printer
  Future<void> _printWithBluetooth(
      Map<String, dynamic> transaction, dynamic user) async {
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

    final company = user?.companyname;
    final address = user?.address;
    final phone = user?.phone;

    try {
      // Set text size for header
      bluetooth.printCustom("$company", 2, 1); // Size 2, Centered
      bluetooth.printNewLine();
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom("$address", 1, 0); // Size 1, Left-aligned
      bluetooth.printNewLine();

      bluetooth.printCustom("Telephone:$phone", 1, 0);
      bluetooth.printCustom("TIN/VAT:101968859", 1, 0);
      bluetooth.printCustom("Email:info@ikwim.com", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      bluetooth.printCustom("Time: ${transaction['time']}", 1, 0);
      bluetooth.printCustom("Site: ${transaction['site_name']}", 1, 0);
      bluetooth.printCustom(
          "Served by:${transaction['l_name']} ${transaction['f_name']}", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      bluetooth.printCustom(
          "Customer names: ${transaction['client_name'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Product: ${transaction['product'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Consumed amount: ${transaction['consumed_amount'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom(
          "Unit price: ${transaction['s_price'] ?? '1647'}", 1, 0);
      bluetooth.printCustom("Quantity: ${transaction['qty'] ?? '0'} L", 1, 0);
      bluetooth.printCustom(
          "Balance amount: ${transaction['balance'] ?? '0'} L", 1, 0);
      bluetooth.printCustom(
          "Plate Number: ${transaction['plate_no'] ?? 'N/A'}", 1, 0);
      bluetooth.printCustom("Type: Bon", 1, 0);
      bluetooth.printCustom("Ref: ${transaction['ref'] ?? 'Unknown'}", 1, 0);
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
    // You may need to adapt this to where your image is stored
    // If there's no tr_image field, use a placeholder or handle it appropriately
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
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
                        _buildDetailItem(
                            'Comapany', user?.companyname.toString() ?? 'dd'),
                        _buildDetailItem(
                            'Date', transaction['time'] ?? 'Unknown'),
                        _buildDetailItem('Customer',
                            transaction['client_name'] ?? 'Unknown'),
                        _buildDetailItem(
                            'Plate Number', transaction['plate_no'] ?? 'N/A'),
                        _buildDetailItem(
                            'Product', transaction['product'] ?? 'N/A'),
                        _buildDetailItem('Unit price',
                            '${transaction['s_price'] ?? 'N/A'} RWF'),
                        _buildDetailItem('Consumed amount',
                            '${transaction['consumed_amount'] ?? 'Unknown'} RWF'),
                        _buildDetailItem('Quantity',
                            '${transaction['qty']?.toString() ?? '0'} L'),
                        _buildDetailItem('Balance amount',
                            '${transaction['balance']?.toString() ?? '0'} RWF'),
                        if (transaction['ref'] != null)
                          _buildDetailItem('Reference', transaction['ref']),
                        if (transaction['l_name'] != null)
                          _buildDetailItem('Served by',
                              '${transaction['l_name']}  ${transaction['f_name']}'),
                        if (transaction['site_name'] != null)
                          _buildDetailItem('Site', transaction['site_name']),
                        // Add any other fields that you have in your API response
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
                        _printTransaction(transaction);
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
        // Divider below each item
        // Divider(height: 1),
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
      return difference.inHours >= 48;
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
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/Sunmi_POS_App_V2/last_saved_invoices'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "operator": user.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        // Parse the JSON response
        final dynamic responseData = json.decode(response.body);
        print('API Response: $responseData');

        // Directly map the response data as a list without checking for success
        if (responseData is List) {
          List<Map<String, dynamic>> transactions =
              List<Map<String, dynamic>>.from(
                  responseData.map((item) => item as Map<String, dynamic>));

          // Filter transactions if needed
          List<Map<String, dynamic>> filteredTransactions = transactions
              .where((transaction) =>
                  !isOlderThan48Hours(transaction['time'] ?? ''))
              .toList();

          setState(() {
            pendingTransactions = filteredTransactions;
            isLoading = false;
          });

          if (filteredTransactions.isEmpty) {
            setState(() {
              errorMessage = 'No recent completed transactions found';
            });
          }
        } else {
          setState(() {
            errorMessage = 'Invalid response format';
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
        print('Error: ${e.toString()}');
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false, // Removes the back button

      //   title: Text(
      //     'Completed Transactions',
      //     style: TextStyle(color: Colors.white),
      //   ),
      //   backgroundColor: const Color(0xFFA50000),
      //   actions: [
      //     IconButton(
      //       icon: Icon(Icons.refresh),
      //       color: Colors.white,
      //       onPressed: fetchCompletedTransactions,
      //       tooltip: 'Refresh',
      //     ),
      //   ],
      // ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : Container(
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
                ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> item, BuildContext context) {
    final String quantity = item['qty']?.toString() ?? '';
    final String items = item['product'] ?? 'Unknown';
    final String plateNo = item['plate_no'] ?? 'Unknown';
    final String lname = item['l_name'] ?? 'Unknown';
    final String fname = item['f_name'] ?? 'Unknown';
    final String client = item['client_name'] ?? 'Unknown';
    final String formattedAmount =
        item['consumed_amount']?.toString() ?? 'Unknown';
    final String date = item['time'] ?? 'Unknown';

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
                        _buildInfoItem(
                          'Served by:',
                          "$lname $fname",
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoItem('Product:', items),
                        const SizedBox(height: 5),
                        _buildInfoItem('Amount:', '$formattedAmount RWF'),
                        const SizedBox(height: 5),
                        _buildInfoItem('Quantity:', '${quantity} L'),
                        const SizedBox(height: 8),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
