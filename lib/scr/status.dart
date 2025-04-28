import 'package:flutter/material.dart';
import 'package:ikwimpay/scr/toptab_status/bon.dart';

import 'package:ikwimpay/scr/toptab_status/compleded.dart';
import 'package:ikwimpay/scr/toptab_status/inProgress.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({Key? key}) : super(key: key);

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF870813),
        automaticallyImplyLeading: false, // Removes the back button

        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
                // color: Colors.white10, // Optional background color for tab bar
                child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF26C6B4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelPadding: const EdgeInsets.symmetric(
                  horizontal: 10), // Adjust spacing between tabs

              labelStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              indicatorWeight: 3,

              tabs: const [
                Tab(text: 'In Progress'),
                Tab(text: 'Completed Card'),
                Tab(text: ' Bon'),
                // Tab(text: 'Canceled'),
              ],
            ))),
      ),
      body: Padding(
          padding: EdgeInsets.all(6),
          child: TabBarView(
            controller: _tabController,
            children: [
              InProgressTab(),
              CompletedTab(),
              BoTab(),
            ],
          )),
    );
  }
}
