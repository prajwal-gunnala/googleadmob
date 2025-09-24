import 'package:flutter/material.dart';

class NestedTabsPage extends StatefulWidget {
  const NestedTabsPage({super.key});

  @override
  State<NestedTabsPage> createState() => _NestedTabsPageState();
}

class _NestedTabsPageState extends State<NestedTabsPage> with TickerProviderStateMixin {
  late TabController _nestedTabController;

  @override
  void initState() {
    super.initState();
    _nestedTabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _nestedTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.orange,
          child: TabBar(
            controller: _nestedTabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.home), text: 'Home'),
              Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.person), text: 'Profile'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _nestedTabController,
            children: [
              _buildTabContent('Home', Icons.home, Colors.blue),
              _buildTabContent('Favorites', Icons.favorite, Colors.red),
              _buildTabContent('Search', Icons.search, Colors.green),
              _buildTabContent('Profile', Icons.person, Colors.purple),
              _buildTabContent('Settings', Icons.settings, Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(String title, IconData icon, Color color) {
    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(60),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 60,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
