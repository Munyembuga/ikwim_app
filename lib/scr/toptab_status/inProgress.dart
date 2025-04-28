import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/providers/globalapi.dart';
import 'package:ikwimpay/scr/completeTranscation.dart';
import 'package:provider/provider.dart';

class InProgressTab extends StatefulWidget {
  const InProgressTab({Key? key}) : super(key: key);

  @override
  State<InProgressTab> createState() => _InProgressTabState();
}

class _InProgressTabState extends State<InProgressTab> {
  List<Map<String, dynamic>> pendingTransactions = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchPendingTransactions();
  }

  Future<void> fetchPendingTransactions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      setState(() {
        errorMessage = 'User not logged in. Please log in to verify tickets.';
        // isVerifying = false;
      });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/transaction/command/pending'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user.userId.toString()}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == 200 && responseData['data'] != null) {
          setState(() {
            pendingTransactions =
                List<Map<String, dynamic>>.from(responseData['data']);
            print(pendingTransactions);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'No pending transactions found';
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
          child: Text(errorMessage, style: const TextStyle(color: Colors.red)));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: pendingTransactions.isEmpty
          ? const Center(
              child: Text(
                'No pending transactions',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchPendingTransactions,
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
    // Create a formatted version of the transaction data
    Map<String, dynamic> formattedData = {
      'transID': item['transID'] ?? 0,
      'nozzle': item['nozzle'] ?? 0,
      'card': item['card'] ?? 0,
      'plate_no': item['plate_no'] ?? 'Unknown',
      'createdAt': item['createdAt'] ?? 'Unknown',
      'product': item['product'] ?? 'Unknown',
    };

    final int transID = item['transID'] ?? 0;
    final String nozzle = item['nozzle_name'] ?? "Unknown";
    final int card = item['card'] ?? 0;
    final String plateNo = item['plate_no'] ?? 'Unknown';
    final String createdAt = item['createdAt'] ?? 'Unknown';
    final String product = item['product'] ?? 'Unknown';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  'Pending',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  createdAt,
                  style: TextStyle(
                      // color: Colors.black,
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
                      _buildInfoItem('Transaction ID:', transID.toString()),
                      const SizedBox(height: 5),
                      _buildInfoItem('Plate No:', plateNo),
                      const SizedBox(height: 5),
                      _buildInfoItem('Product:', product),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoItem('Nozzle:', nozzle.toString()),
                      const SizedBox(height: 5),
                      // _buildInfoItem('Card:', card.toString()),
                      const SizedBox(height: 5),
                      _buildInfoItem('Date:', createdAt),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Correctly navigate to TransactionFormScreen with required parameters
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(
                        nozzleidCard: nozzle,
                        transactionData: formattedData,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF870813),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Complete Transaction'),
              ),
            ),
          ],
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
