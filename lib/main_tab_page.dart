import 'package:flutter/material.dart';
import 'features/media/media_tab.dart';
import 'features/nested_tabs/nested_tabs_page.dart';
import 'features/rewards/rewards_tab.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> with TickerProviderStateMixin {
  late TabController _mainTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdMob Demo'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _mainTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.perm_media),
              text: 'Media',
            ),
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Nested Tabs',
            ),
            Tab(
              icon: Icon(Icons.card_giftcard),
              text: 'Rewards',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: const [
          MediaTab(),
          NestedTabsPage(),
          RewardsTab(),
        ],
      ),
    );
  }
}
