import 'package:flutter/material.dart';
import '../config/breakpoints.dart';
import '../services/storage_service.dart';
import 'channel_list_screen.dart';
import 'add_source_screen.dart';

class ResponsiveHome extends StatefulWidget {
  const ResponsiveHome({super.key});

  @override
  State<ResponsiveHome> createState() => _ResponsiveHomeState();
}

class _ResponsiveHomeState extends State<ResponsiveHome> {
  int _selectedIndex = 0;
  int _refreshKey = 0;

  final List<Map<String, dynamic>> _menuItems = const [
    {'icon': Icons.live_tv, 'label': 'القنوات'},
    {'icon': Icons.favorite, 'label': 'المفضلة'},
    {'icon': Icons.settings, 'label': 'الإعدادات'},
  ];

  @override
  Widget build(BuildContext context) {
    final screen = ScreenConfig.of(context);
    final isLarge = screen != ScreenType.mobile;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          if (isLarge) _buildNavigationRail(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isLarge ? _buildBottomNav() : null,
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF3B82F6),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSourceScreen()),
                );
                if (result == true) {
                  setState(() => _refreshKey++);
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ChannelListScreen(key: ValueKey('channels_$_refreshKey'));
      case 1:
        return ChannelListScreen(key: ValueKey('fav_$_refreshKey'));
      case 2:
        return _settingsPage();
      default:
        return const SizedBox();
    }
  }

  Widget _settingsPage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('الإعدادات',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _settingTile(
          icon: Icons.refresh,
          title: 'إعادة تحميل القنوات',
          subtitle: 'تحميل المصادر من جديد',
          onTap: () {
            setState(() {
              _refreshKey++;
              _selectedIndex = 0;
            });
          },
        ),
        _settingTile(
          icon: Icons.delete_sweep,
          title: 'مسح القنوات المخزنة',
          subtitle: 'حذف كل القنوات المحفوظة محلياً',
          color: Colors.orange,
          onTap: () async {
            await StorageService.clearChannels();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح القنوات المخزنة')),
              );
              setState(() => _refreshKey++);
            }
          },
        ),
        _settingTile(
          icon: Icons.delete_forever,
          title: 'مسح كل شيء',
          subtitle: 'حذف المصادر + القنوات + المفضلة',
          color: Colors.red,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1F2937),
                title: const Text('تأكيد',
                    style: TextStyle(color: Colors.white)),
                content: const Text('سيتم حذف كل البيانات. متابعة؟',
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حذف',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await StorageService.clearChannels();
              await StorageService.saveSources([]);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم مسح كل البيانات')),
                );
                setState(() => _refreshKey++);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        onTap: onTap,
      ),
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
      destinations: _menuItems.map((item) {
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
                fontWeight: FontWeight.bold,
              )),
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
}
