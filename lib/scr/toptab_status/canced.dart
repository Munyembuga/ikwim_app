import 'package:flutter/material.dart';

class CanceledTab extends StatelessWidget {
  final List<Map<String, dynamic>> canceledItems;
  final Function(Map<String, dynamic>) onItemTap;

  const CanceledTab({
    Key? key,
    required this.canceledItems,
    required this.onItemTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return canceledItems.isEmpty
        ? const Center(
            child: Text(
              'No canceled scans',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: canceledItems.length,
            itemBuilder: (context, index) {
              final item = canceledItems[index];
              return _buildStatusCard(item, context);
            },
          );
  }

  Widget _buildStatusCard(Map<String, dynamic> item, BuildContext context) {
    final String title = item['title'] as String;
    final String date = item['date'] as String;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.close, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Date: $date'),
        trailing: const Chip(
          label: Text('Canceled', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
        onTap: () => onItemTap(item),
      ),
    );
  }
}
