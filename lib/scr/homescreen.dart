import 'package:flutter/material.dart';
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/scr/NFCTapCard.dart';
import 'package:ikwimpay/scr/detectDisplay.dart';
// import 'package:ikwimpay/scr/detectDisplay.dart';
import 'package:ikwimpay/scr/firstScreen.dart';
import 'package:ikwimpay/scr/qrCodeScanner.dart';
import 'package:ikwimpay/scr/status.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex; // Add this parameter

  const HomeScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // Set the initial tab
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white, // Background color of the bar
        elevation: 10, // Add shadow
        type: BottomNavigationBarType.fixed, // Keep items fixed in position
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 10,
        ),
        showUnselectedLabels: true, //
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge),
            label: 'Card',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Bon',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Transaction',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const Firstscreen();
      case 1:
        return const NFCScreen();
      case 2:
        return QrCodeTab();
      case 3:
        return const StatusTab();
      default:
        return const Firstscreen();
    }
  }
}
