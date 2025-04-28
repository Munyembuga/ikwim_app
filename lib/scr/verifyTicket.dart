import 'dart:math';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/homescreen.dart';
import 'package:ikwimpay/scr/plateScanner.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';

import '../providers/auth_provider.dart';

class Verifyticket extends StatefulWidget {
  final dynamic verificationResult;
  final List<String>? scannedCode; // Changed to List<String>? for array
  final List<String>? coupId; // Changed to List<String>? for array
  final List<double> ticketAmounts; // New parameter for ticket amounts array
  final int successfulScansCount; // Add this parameter

  const Verifyticket(
      {super.key,
      required this.verificationResult,
      required this.scannedCode,
      required this.coupId,
      required this.ticketAmounts,
      required this.successfulScansCount});

  // Named constructor without parameters
  const Verifyticket.without({super.key})
      : verificationResult = '',
        scannedCode = const [],
        coupId = const [],
        ticketAmounts = const [],
        successfulScansCount = 0; // New parameter for ticket amounts array
  // Initialize as empty array
  @override
  State<Verifyticket> createState() => _VerifyticketState();
}

class _VerifyticketState extends State<Verifyticket> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? responseMessage;
  bool isSuccess = false;
  bool isVerifying = false;
  String? errorMessage;
  double _ticketAmount = 0.0;
  String? _savedPlateNumber;
  Map<String, dynamic>? _updateResult;
  double? _quantity;
  String _productName = "";
  double? _totalPrice;
  // final List<double> ticketAmounts; // New parameter for ticket amounts array

  // Form controllers
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _productController = TextEditingController();

  // Selected product
  String _selectedProduct = "1";
  List<Map<String, dynamic>> _products = [];
  String? _selectedProductId;
  bool _isProductLoading = true;
  bool _isPaymentEnabled = true;
  String assign_id = "";
  bool _isFullPayment = true;
  final List<String> _paymentTypes = ['Full', 'Not Full'];
  String _selectedPaymentType = 'Full';
  @override
  void initState() {
    super.initState();

    _isPaymentEnabled = !_isFullPayment;

    if (_isFullPayment && _ticketAmount != 0) {
      _paymentController.text = _ticketAmount.toString();
      _updateBalance();
    }
    _paymentController.addListener(_updateBalance);
    _paymentController.addListener(_updatequantity);
    final tokenList = widget.scannedCode ?? [];
    final CoupIDList = widget.coupId ?? [];
    final amountList = widget.ticketAmounts ?? [];
    final lengthofTicketScanned = widget.successfulScansCount ?? 0;
    print("%%%%%%%%%%%%%%%%% $tokenList");
    print("%%%%%%%%%%%%%%%%% $CoupIDList");
    print("%%%%%%%%%%%%%%%%ggggggggggggggggggggg $amountList");
    print("%%%%%%%%%%%%%%%%ggggggggggggggggggggg $lengthofTicketScanned");

    final ticketAmountValue = widget.verificationResult?['totalAmount'];
    final ticketPin = widget.verificationResult?['pin'];
    print('****************** ${ticketPin}');
    if (ticketAmountValue != null) {
      _ticketAmount = ticketAmountValue is double
          ? ticketAmountValue
          : ticketAmountValue.toDouble();
    }

    _paymentController.text = _ticketAmount.toString();

    _isPaymentEnabled = !_isFullPayment; // Should be false by default

    _balanceController.text =
        (_ticketAmount - double.parse(_paymentController.text))
            .toStringAsFixed(2);

    _paymentController.addListener(_updateBalance);
    _paymentController.addListener(_updatequantity);

    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await fetchProducts(context);
      setState(() {
        _products = products;
        _isProductLoading = false;

        // Set a default selected product if available
        if (_products.isNotEmpty) {
          _selectedProductId = _products.first['id'];
          _productController.text = _selectedProductId ?? '';
          assign_id = _products.first['assign_id']?.toString() ?? '';
          _productName = _products.first['name'] ?? 'Unnamed Product';
        }
      });
    } catch (e) {
      setState(() {
        _isProductLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }

  void _updatequantity() {
    if (_paymentController.text.isNotEmpty && _selectedProductId != null) {
      // Find the selected product
      final selectedProduct = _products.firstWhere(
        (product) => product['id'] == _selectedProductId,
        orElse: () => {},
      );

      print('Selected Product: $selectedProduct');

      if (selectedProduct.isNotEmpty && selectedProduct['price'] != null) {
        double paymentAmount = double.tryParse(_paymentController.text) ?? 0.0;
        double productPrice =
            double.tryParse(selectedProduct['price'].toString()) ?? 0.0;

        print('Payment Amount: $paymentAmount');
        print('Product Price: $productPrice');

        // Make sure product price is not zero to avoid division by zero
        if (productPrice > 0) {
          double quantity = paymentAmount / productPrice;
          print('Calculated Quantity: $quantity');

          setState(() {
            _qtyController.text = quantity.toStringAsFixed(2);
          });
        } else {
          print('ERROR: Product price is zero or invalid');
          setState(() {
            _qtyController.text = '0';
          });
        }
      } else {
        print('ERROR: Selected product not found or has no price');
      }
    }
  }

  void _updateBalance() {
    if (_paymentController.text.isNotEmpty) {
      double paymentAmount = double.tryParse(_paymentController.text) ?? 0.0;
      double newBalance = _ticketAmount - paymentAmount;
      // _balanceController.text = newBalance.toStringAsFixed(2);
      _balanceController.text =
          newBalance > 0 ? newBalance.toStringAsFixed(2) : "0.0";
    } else {
      _balanceController.text = _ticketAmount.toStringAsFixed(2);
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProducts(
      BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final url = Uri.parse(
        '${AppConfig.baseUrl}/Sunmi_POS_App_V2/products?site_id=${user?.siteId}');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("HHHHHHHHHHHHHHHHH ${response.body}");

        final Map<String, dynamic> responseData = jsonDecode(response.body);

        final List<dynamic> productList = responseData['products'] ?? [];

        return productList
            .map((product) => {
                  'id': product['item_id']?.toString(),
                  'name': product['item_name'] ?? 'Unnamed Product',
                  'code': product['category_name'] ?? '',
                  'unit': product['category_unit']?.toString() ?? '',
                  'price': product['s_price']?.toString() ?? '',
                  'class': product['class_name'] ?? '',
                  "assign_id": product['assign_id'] ?? '',
                })
            .toList();
      } else {
        // Handle error
        print('Failed to fetch products. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      // Handle network or parsing errors
      print('Error fetching products: $e');
      return [];
    }
  }

  String getInvoiceId() {
    final random = Random();
    final buffer = StringBuffer();

    // Generate 9 random digits
    for (int i = 0; i < 9; i++) {
      buffer.write(random.nextInt(10));
    }

    // Get current date and time components
    final now = DateTime.now();
    final month = now.month; // 1-12
    final day = now.day; // 1-31
    final hour = now.hour; // 0-23
    final minute = now.minute; // 0-59

    // Format and append date/time components
    final dateTimePart = '${month.toString().padLeft(2, '0')}' +
        '${day.toString().padLeft(2, '0')}' +
        '${hour.toString().padLeft(2, '0')}' +
        '${minute.toString().padLeft(2, '0')}';

    return buffer.toString() + dateTimePart;
  }

  Future<void> submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Final check for quantity calculation before submission
      if (_qtyController.text == "0" ||
          double.parse(_qtyController.text) == 0) {
        if (double.parse(_paymentController.text) > 0) {
          // Force recalculation of quantity
          final selectedProduct = _products.firstWhere(
            (product) => product['id'] == _selectedProductId,
            orElse: () => {},
          );

          if (selectedProduct.isNotEmpty && selectedProduct['price'] != null) {
            double productPrice;
            try {
              productPrice = double.parse(selectedProduct['price'].toString());
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid product price format')),
              );
              return;
            }

            double paymentAmount = double.parse(_paymentController.text);

            if (productPrice > 0) {
              setState(() {
                _qtyController.text =
                    (paymentAmount / productPrice).toStringAsFixed(2);
              });
              print("Fixed quantity calculation: ${_qtyController.text}");
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Cannot calculate quantity - product price is zero')),
              );
              return;
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Cannot calculate quantity - product not found')),
            );
            return;
          }
        }
      }

      setState(() {
        isLoading = true;
        responseMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final tokenList = widget.scannedCode ?? [];
      final CoupIDList = widget.coupId ?? [];

      final pin = widget.verificationResult?['client']?['pin'] ?? 'Unknown';

      try {
        if (user == null) {
          throw Exception("User is not authenticated");
        }

        dynamic paymentValue;
        if (widget.successfulScansCount > 1) {
          // Create an array with length equal to successfulScansCount
          double actualPayment = double.parse(_paymentController.text);
          paymentValue = List<double>.filled(widget.successfulScansCount, 0.0);
          // Set the last element to the actual payment amount
          paymentValue[widget.successfulScansCount - 1] = actualPayment;
        } else {
          // For a single scan, use the regular payment value
          paymentValue = double.parse(_paymentController.text);
        }
        final paymentValuesss = [_paymentController.text];

        dynamic balanceValue;
        if (widget.successfulScansCount > 1) {
          // Create an array with length equal to successfulScansCount
          double actualBalance = double.parse(_balanceController.text);
          balanceValue = List<double>.filled(widget.successfulScansCount, 0.0);
          // Set the last element to the actual balance
          balanceValue[widget.successfulScansCount - 1] = actualBalance;
        } else {
          // For a single scan, use the regular balance value
          paymentValue = [double.parse(_paymentController.text)];
        }
        print('balanceValue *******************; $balanceValue');
        // Prepare request body for updateCoupon
        Map<String, dynamic> requestBody = {
          "token": tokenList,
          'userRole': user.role.toString(),
          'userId': user.userId.toString(),
          "driver_name": _driverNameController.text,
          "pin": _pinController.text,
          "product": _productName,
          "plateNumber": _plateNumberController.text,
          "qty": _qtyController.text,
          "ref": getInvoiceId(),
          // "balance": _balanceController.text,
          "balance": balanceValue,
          "payMont": paymentValue,
          "couponIds": CoupIDList
        };

        print("Using assign_id: $assign_id");
        print("Request body - quantity: ${requestBody['qty']}");

        // Send the POST request to updateCoupon
        final response = await http.post(
          Uri.parse(
              '${AppConfig.baseUrl}/Sunmi_POS_App_V2/api.php/updateCoupon'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );
        print("updateCoupon request body: $requestBody");

        if (response.statusCode == 200) {
          print('***************7777 ${response.body}');
          final result = jsonDecode(response.body);
          print("updateCoupon response: $result");

          if (result['status'] == 'OK') {
            _updateResult = {
              ...requestBody,
              'timestamp': DateTime.now().toString(),
              'ticketAmount': _ticketAmount.toString(),
              'receiptNo':
                  'RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
              'clientDetails': widget.verificationResult?['client']
            };

            await _validateTransaction(result);

            setState(() {
              isSuccess = true;
              responseMessage = "Ticket verified successfully!";
            });
          } else {
            setState(() {
              isSuccess = false;
              responseMessage = "Verification failed: ${result['message']}";
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Update failed: ${result['message']}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            isSuccess = false;
            responseMessage =
                "Verification failed. Server returned ${response.statusCode}";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: ${response.statusCode}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print("Error: ${e.toString()}");
        print("JSON decode error: $e");
        print("Response body that caused error:");
        setState(() {
          isSuccess = false;
          responseMessage = "Error: ${e.toString()}";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _validateTransaction(Map<String, dynamic> updateResult) async {
    final custId = widget.verificationResult?['clientId']?.toString();
    print("FFFFFFFFFFFF $_productName");

    print("**************** $custId");

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception("User is not authenticated");
      }

      final selectedProduct = _products.firstWhere(
        (product) => product['id'] == _selectedProductId,
        orElse: () => {},
      );
      _totalPrice = double.parse(_paymentController.text);

      final customerId = widget.verificationResult?['client']?['id'] ?? '0';
      print('UUUUUUUUUUUUUUUUUUU  $customerId');
      // Prepare request body for val_trans
      Map<String, dynamic> valTransBody = {
        'assign_id': assign_id,
        'qty': _qtyController.text,
        'price_id': _selectedProductId ?? '0',
        'totalAmount': _totalPrice ?? 0,
        'ste_id': user.siteId.toString(),
        'co_id': user.cpyid.toString(),
        'customer_id': custId.toString(),
        'rec_by': user.userId.toString(),
        'balance': _balanceController.text,
        'plate_no': _plateNumberController.text,
        'ref': getInvoiceId(),
        'product': _productName,
      };

      print("val_trans request body: $valTransBody");

      // Send the POST request to val_trans
      final valTransResponse = await http.post(
        Uri.parse('${AppConfig.baseUrl}/Sunmi_POS_App_V2/api.php/val_trans'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(valTransBody),
      );

      if (valTransResponse.statusCode == 200) {
        final valTransResult = jsonDecode(valTransResponse.body);
        print("val_trans response: $valTransResult");

        if (valTransResult['status'] == 'ok') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          print("Transaction validation successful!");
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(initialIndex: 3),
              ));
        } else {
          print("Transaction validation warning: ${valTransResult['message']}");
        }
      } else {
        print(
            "Transaction validation failed with status code: ${valTransResponse.statusCode}");
        print("Response body: ${valTransResponse.body}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Transaction validation failed: ${valTransResponse.statusCode}'),
            backgroundColor:
                Colors.orange, // Use orange to indicate partial success
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error in transaction validation: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction validation error: ${e.toString()}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _printTransaction() async {
    setState(() {
      // _isLoading = true;
      // _status = "Printing...";
    });

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.printText("IkWIM ENERGIES",
          style: SunmiTextStyle(
              bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.printText("--------------------------------");

      await SunmiPrinter.printText(
          'Driver name: ${_updateResult?['driver_name']}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText('Plate No: ${_updateResult?['plateNumber']}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          'Product: ${_getProductName(_updateResult?['product'])}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(30); // Add one line of space
      await SunmiPrinter.printText(
          'product: ${_getProductName(_updateResult?['product'])}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText('Quantity: ${_updateResult?['qty']}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText(
          'Total: RWF ${_formatCurrency(_ticketAmount)}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.printText(
          'Balance: ${_formatCurrency(double.tryParse(_updateResult?['balance'] ?? '0') ?? 0.0)}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));
      await SunmiPrinter.printText(
          'Total: RWF ${_formatCurrency(_ticketAmount)}',
          style: SunmiTextStyle(
            fontSize: 30,
          ));

      await SunmiPrinter.lineWrap(30); // Add one line of space

      await SunmiPrinter.printText("--------------COPY-------------");
      await SunmiPrinter.lineWrap(7); // Add one line of space

      await SunmiPrinter.printText("\nYour full satisfaction is our mission ",
          style: SunmiTextStyle(
            align: SunmiPrintAlign.CENTER,
          ));

      await SunmiPrinter.lineWrap(7); // Add one line of space
      await SunmiPrinter.cutPaper();

      setState(() {
        // _status = "Printed successfully";
      });

      // Return to the previous screen after printing
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        // _status = "Print error: ${e.toString()}";
      });
    } finally {
      setState(() {
        // _isLoading = false;
      });
    }
  }

  // Show dialog to print or continue

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

  Future<void> _loadSavedPlateNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPlateNumber = prefs.getString('plateNumber');
      if (_savedPlateNumber != null) {
        _plateNumberController.text = _savedPlateNumber!;
      }
    });
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _getProductName(String? productId) {
    if (productId == null || productId.isEmpty) return 'N/A';

    // Find the product in the products list
    final product = _products.firstWhere(
      (p) => p['id'] == productId,
      orElse: () => {'name': 'Unknown Product'},
    );

    return product['name'] ?? 'Unknown Product';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.verificationResult?['status'] ?? 'Unknown';
    final ticketAmount =
        widget.verificationResult?['ticketAmout']?.toString() ?? 'Unknown';

    // Access the scanned QR code

    return Scaffold(
        appBar: AppBar(
          title: const Text('',
              style: TextStyle(
                color: Colors.white,
              )),
          // backgroundColor: const Color(0xFF0A1933),
          backgroundColor: const Color(0xFFA50000),

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
        body: SafeArea(
            child: Center(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(15.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Form Title
                      const Text(
                        'Ticket Update ',
                        style: TextStyle(
                          // color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Text(
                          'Total amount: ',
                          style: TextStyle(
                            // color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_ticketAmount.toString()} RWF',
                          style: TextStyle(
                            // color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),

                      // Driver Name
                      _buildTextFieldPlateNumber(
                        controller: _plateNumberController,
                        hintText: 'RAD670D',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter plate number';
                          }
                          return null;
                        },
                      ),
                      // Plate Number
                      const SizedBox(height: 20),

                      // Quantity
                      _buildTextField(
                        controller: _driverNameController,
                        hintText: 'Enter Driver ',
                        labelText: "Driver name",
                        keyboardType: TextInputType.text,
                        readOnly: false,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter Driver name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildTextField(
                        controller: _pinController,
                        hintText: 'Enter Pin',
                        labelText: 'Pin',
                        keyboardType: TextInputType.number,
                        readOnly: false,
                        validator: (value) {
                          final ticketPin =
                              widget.verificationResult?['pin']?.toString();

                          if (value == null || value.isEmpty) {
                            return 'Please enter pin';
                          }

                          if (ticketPin != null && value != ticketPin) {
                            return 'Pin does not match';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 10),
                      _buildProductDropdown(),

                      // Plate Number
                      const SizedBox(height: 10),

                      // Quantity
                      _buildTextField(
                        controller: _qtyController,
                        hintText: 'Quantity',
                        labelText: "Quantity",
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildPaymentTypeDropdown(),
                      SizedBox(
                        height: 10,
                      ),
                      _buildTextField(
                        controller: _paymentController,
                        hintText: 'Payment Amount',
                        labelText: 'Payment Amount',
                        keyboardType: TextInputType.number,
                        enabled: _isPaymentEnabled,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter payment amount';
                          }

                          double? paymentAmount = double.tryParse(value);
                          double? ticketAmount =
                              double.tryParse(_balanceController.text);

                          if (paymentAmount == null) {
                            return 'Please enter a valid number';
                          }

                          if (_ticketAmount != null &&
                              paymentAmount > _ticketAmount) {
                            return 'Payment cannot exceed $_ticketAmount';
                          }

                          return null;
                        },
                      ),
                      // Balance
                      const SizedBox(height: 10),

                      _buildTextField(
                        controller: _balanceController,
                        hintText: 'Balance',
                        labelText: 'Balance',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA50000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'UPDATE TICKET',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )));
  }

  Widget _buildPaymentTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Payment Type',
          border: InputBorder.none,
        ),
        value: _selectedPaymentType, // Will be 'Full' by default
        items: _paymentTypes.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedPaymentType = newValue!;
            _isFullPayment = newValue == 'Full';

            if (_isFullPayment) {
              _paymentController.text = _ticketAmount.toString();
              _isPaymentEnabled = false;
            } else {
              _isPaymentEnabled = true;
            }

            // Make sure balance is recalculated
            _updateBalance();
            _updatequantity();
          });
        },
      ),
    );
  }

  Widget _buildPaymentField() {
    return _buildTextField(
      controller: _paymentController,
      hintText: 'Payment Amount',
      labelText: 'Payment Amount',
      keyboardType: TextInputType.number,
      readOnly:
          _isFullPayment, // Should be readonly by default for full payment
      enabled:
          !_isFullPayment, // Should be disabled by default for full payment
      onChanged: (value) {
        _updateBalance();
        _updatequantity();
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter payment amount';
        }

        double? paymentAmount = double.tryParse(value);

        if (paymentAmount == null) {
          return 'Please enter a valid number';
        }

        if (_ticketAmount != null && paymentAmount > _ticketAmount) {
          return 'Payment cannot exceed $_ticketAmount';
        }

        return null;
      },
    );
  }

  Widget _buildTextFieldPlateNumber(
      {required TextEditingController controller,
      required String hintText,
      String? Function(String?)? validator,
      TextInputType keyboardType = TextInputType.text,
      bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(
          color: Colors.black38, fontWeight: FontWeight.w400, fontSize: 14),
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
          tooltip: 'Scan plate  with camera',
        ),
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 7,
      validator: validator,
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String hintText,
      required labelText,
      bool enabled = true, // Add this parameter with default true

      String? Function(String?)? validator,
      TextInputType keyboardType = TextInputType.text,
      void Function(String)? onChanged, // Added this parameter

      bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(
          color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: const TextStyle(
            color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        errorStyle: const TextStyle(
            color: Colors.redAccent, fontWeight: FontWeight.w400, fontSize: 10),
      ),
      validator: validator,
    );
  }

  Widget _buildProductDropdown() {
    if (_isProductLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFA50000),
        ),
      );
    }

    if (_products.isEmpty) {
      return TextFormField(
        controller: _productController,
        decoration: InputDecoration(
          labelText: 'Product',
          hintText: 'No products available',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        readOnly: true,
      );
    }

    return DropdownSearch<String>(
      items: (filter, infiniteScrollProps) =>
          _products.map((product) => product['id'] as String).toList(),
      selectedItem: _selectedProductId,
      itemAsString: (productId) {
        final product = _products.firstWhere(
          (p) => p['id'] == productId,
          orElse: () => {'name': 'Unknown Product'},
        );
        return product['name'] as String;
      },
      // In the onChanged callback of DropdownSearch
      onChanged: (value) {
        setState(() {
          _selectedProductId = value;
          _productController.text = value ?? '';

          if (value != null) {
            final selectedProduct = _products.firstWhere(
              (product) => product['id'] == value,
              orElse: () => {'assign_id': '', 'name': 'Unknown Product'},
            );
            assign_id = selectedProduct['assign_id']?.toString() ?? '';
            _productName = selectedProduct['name'] ?? 'Unknown Product';
          }
          _updatequantity();

          // _paymentController.clear();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a product';
        }
        return null;
      },
      suffixProps: DropdownSuffixProps(
        dropdownButtonProps: DropdownButtonProps(
          iconClosed: Icon(Icons.keyboard_arrow_down),
          iconOpened: Icon(Icons.keyboard_arrow_up),
        ),
      ),
      decoratorProps: DropDownDecoratorProps(
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          labelText: 'Product',
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFA50000)),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          hintText: 'Select Product',
          hintStyle: TextStyle(
              fontWeight: FontWeight.normal, fontSize: 14, color: Colors.grey),
        ),
      ),
      popupProps: PopupProps.menu(
        itemBuilder: (context, productId, isDisabled, isSelected) {
          final product = _products.firstWhere(
            (p) => p['id'] == productId,
            orElse: () => {'name': 'Unknown Product'},
          );

          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product['name'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? Color(0xFFA50000) : Colors.black,
                  ),
                ),
              ],
            ),
          );
        },
        constraints: BoxConstraints(maxHeight: 300),
        menuProps: MenuProps(
          margin: EdgeInsets.only(top: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
      ),
    );
  }
}
