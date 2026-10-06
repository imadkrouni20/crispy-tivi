import 'package:flutter/material.dart';
import '../config/breakpoints.dart';

class ResponsiveHome extends StatefulWidget {
  const ResponsiveHome({super.key});

  @override
  State<ResponsiveHome> createState() => _ResponsiveHomeState();
}

class _ResponsiveHomeState extends State<ResponsiveHome> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = const [
    {'icon': Icons.live_tv, 'label': 'البث المباشر'},
    {'icon': Icons.movie, 'label': 'الأفلام'},
    {'icon': Icons.tv, 'label': 'المسلسلات'},
    {'icon': Icons.calendar_today, 'label': 'دليل البرامج'},
    {'icon': Icons.favorite, 'label': 'المفضلة'},
    {'icon': Icons.settings, 'label': 'الإعدادات'},
  ];

  @override
  Widget build(BuildContext context) {
    final screen = ScreenConfig.of(context);
    final isLarge = screen == ScreenType.tablet ||
        screen == ScreenType.desktop ||
        screen == ScreenType.tv;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          if (isLarge) _buildNavigationRail(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isLarge ? _buildBottomNav() : null,
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      extended: ScreenConfig.of(context) == ScreenType.tv,
      backgroundColor: const Color(0xFF111827),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      indicatorColor: const Color(0xFF3B82F6),
      labelType: NavigationRailLabelType.all,
      destinations: _menuItems
          .map((item) => NavigationRailDestination(
                icon: Icon(item['icon'] as IconData, color: Colors.white70),
                selectedIcon:
                    Icon(item['icon'] as IconData, color: Colors.white),
                label: Text(item['label'] as String,
                    style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      backgroundColor: const Color(0xFF111827),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: _menuItems.take(5).map((item) {
        return NavigationDestination(
          icon: Icon(item['icon'] as IconData, color: Colors.white54),
          selectedIcon: Icon(item['icon'] as IconData,
              color: const Color(0xFF3B82F6)),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final padding = ScreenConfig.horizontalPadding(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      color: const Color(0xFF111827),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill,
              color: Color(0xFF3B82F6), size: 32),
          const SizedBox(width: 12),
          const Text('IPTV Pro',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final columns = ScreenConfig.gridColumns(context);
    final padding = ScreenConfig.horizontalPadding(context);
    final cardHeight = ScreenConfig.cardHeight(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('القنوات المميزة',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 16 / 10,
            ),
            itemCount: 12,
            itemBuilder: (context, i) => _channelCard(i, cardHeight),
          ),
        ],
      ),
    );
  }

  Widget _channelCard(int index, double height) {
    return Focus(
      child: Builder(builder: (context) {
        final hasFocus = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus ? const Color(0xFF3B82F6) : Colors.transparent,
              width: 3,
            ),
            boxShadow: hasFocus
                ? [
                    BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.5),
                        blurRadius: 20)
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              Text('قناة ${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        );
      }),
    );
  }
}
