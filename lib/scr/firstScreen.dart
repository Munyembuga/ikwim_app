import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/cardViewPump.dart';
import 'package:ikwimpay/scr/userProfile';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class Firstscreen extends StatefulWidget {
  const Firstscreen({Key? key}) : super(key: key);

  @override
  _FirstscreenState createState() => _FirstscreenState();
}

class _FirstscreenState extends State<Firstscreen> {
  List<dynamic> pump = [];
  bool isLoading = false;
  int? _userRole;
  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final userSite = authProvider.user?.siteId;
    print("&&&&&&&&&&&&&&& $userSite");
    // Fetch nozzles when the screen initializes
    fetchNozzlesIfNeeded();
  }

  Future<void> fetchNozzlesIfNeeded() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role;
    final userSite = authProvider.user?.siteId;
    _userRole = userRole;
    // Check if user has role 5
    if (userRole == 5) {
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
          body: json.encode({'site': userSite}),
        );
        print('Response body: ${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            pump = data['data'];
            print(
                "&&&&&&&&&&&&&&&&&&& ${data['data']}"); // Fixed string interpolation
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
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user?.role.toString();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Red Section
            Container(
              color: const Color(0xFF870813),
              child: SafeArea(
                child: Column(
                  children: [
                    // Profile and Logo Row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const ProfileSection(),
                          Image.asset(
                            'assets/images/ikwim_tr.png',
                            height: 70,
                            width: 70,
                            fit: BoxFit.cover,
                          ),
                        ],
                      ),
                    ),
                    // Welcome Text
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Center(
                        child: Text(
                          'Welcome to ITEC Tab',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Post-paid, Pre-paid, Master Icons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPaymentOption('POST PAID', Icons.description),
                          _buildPaymentOption('PRE-PAID', Icons.description),
                          _buildPaymentOption('MASTER', Icons.description),
                          _buildPaymentOption('Royalty', Icons.description),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Add SizedBox and condition here
            SizedBox(
              height: 10,
            ),
            _userRole == 6
                ? Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height /
                        2, // Use full screen height
                    padding:
                        EdgeInsets.all(10.0), // Added padding around all sides

                    child: Image.asset(
                      'assets/images/ikwim2.jpeg',
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(height: 10),
                      Center(child: Text("List of pump")),
                      SizedBox(height: 10),
                      isLoading
                          ? CircularProgressIndicator()
                          : pump.isEmpty
                              ? Text("No pumps found")
                              : Column(
                                  children: pump.map<Widget>((item) {
                                    return _buildPumpCard(item);
                                  }).toList(),
                                ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpCard(Map<String, dynamic> pumpData) {
    final pumpName = pumpData['pomp_name'] ?? 'Unknown Pump';
    final pumpId = pumpData['pomp_id']?.toString() ?? 'N/A';
    final siteName = pumpData['site_name'] ?? 'Unknown Site';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => DetailedCardView(
                      pumpId: pumpData['pomp_id'],
                    )),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_gas_station, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Pump ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoItem('Name:', pumpName),
                        SizedBox(height: 4),
                        _buildInfoItem('Site:', siteName),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String text, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
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
