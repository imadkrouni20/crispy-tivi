import 'package:flutter/material.dart';
import '../config/breakpoints.dart';
import '../services/storage_service.dart';
import 'channel_list_screen.dart';
import 'add_source_screen.dart';
import 'xtream_login_screen.dart';

class ResponsiveHome extends StatefulWidget {
  const ResponsiveHome({super.key});

  @override
  State<ResponsiveHome> createState() => _ResponsiveHomeState();
}

class _ResponsiveHomeState extends State<ResponsiveHome> {
  int _selectedIndex = 0;
  int _refreshKey = 0;

  final List<Map<String, dynamic>> _menuItems = const [
    {'icon': Icons.live_tv, 'label': 'مباشر'},
    {'icon': Icons.movie, 'label': 'أفلام'},
    {'icon': Icons.video_library, 'label': 'مسلسلات'},
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
      floatingActionButton: _selectedIndex <= 2
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF3B82F6),
              onPressed: _showAddDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('إضافة مصدر',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sheetTile(
              icon: Icons.vpn_key,
              color: const Color(0xFF3B82F6),
              title: 'Xtream Codes',
              subtitle: 'تسجيل باليوزر والباسورد (موصى به)',
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const XtreamLoginScreen()),
                );
                if (ok == true) setState(() => _refreshKey++);
              },
            ),
            const SizedBox(height: 12),
            _sheetTile(
              icon: Icons.playlist_play,
              color: const Color(0xFF10B981),
              title: 'رابط M3U',
              subtitle: 'قائمة تشغيل بصيغة m3u/m3u8',
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddSourceScreen()),
                );
                if (ok == true) setState(() => _refreshKey++);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ChannelListScreen(
          key: ValueKey('live_$_refreshKey'),
          contentType: 'live',
        );
      case 1:
        return ChannelListScreen(
          key: ValueKey('vod_$_refreshKey'),
          contentType: 'vod',
        );
      case 2:
        return ChannelListScreen(
          key: ValueKey('series_$_refreshKey'),
          contentType: 'series',
        );
      case 3:
        return ChannelListScreen(
          key: ValueKey('fav_$_refreshKey'),
          favoritesOnly: true,
        );
      case 4:
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
          icon: Icons.vpn_key,
          title: 'Xtream Codes',
          subtitle: 'تسجيل دخول / تسجيل خروج',
          onTap: () async {
            final ok = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const XtreamLoginScreen()),
            );
            if (ok == true) setState(() => _refreshKey++);
          },
        ),
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
          subtitle: 'حذف المصادر + القنوات + المفضلة + Xtream',
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
              await StorageService.clearAll();
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
