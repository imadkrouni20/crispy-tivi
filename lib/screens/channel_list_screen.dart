import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import '../services/storage_service.dart';
import '../config/breakpoints.dart';
import 'player_screen.dart';

class ChannelListScreen extends StatefulWidget {
  final bool forceRefresh;
  const ChannelListScreen({super.key, this.forceRefresh = false});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  List<Channel> _channels = [];
  List<Channel> _filtered = [];
  bool _loading = true;
  List<String> _favorites = [];
  String _currentGroup = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _loading = true);
    _favorites = await StorageService.loadFavorites();

    var channels = await StorageService.loadChannels();

    if (channels.isEmpty || widget.forceRefresh) {
      final sources = await StorageService.loadSources();
      if (sources.isNotEmpty) {
        try {
          final all = <Channel>[];
          for (final src in sources) {
            try {
              final parsed = await M3UParser.parseFromUrl(src);
              all.addAll(parsed);
            } catch (e) {
              debugPrint('خطأ في المصدر $src: $e');
            }
          }
          channels = all;
          await StorageService.saveChannels(channels);
        } catch (e) {
          debugPrint('خطأ: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _channels = channels;
        _filtered = channels;
        _loading = false;
      });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _channels
          : _channels
              .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cols = ScreenConfig.gridColumns(context);
    final padding = ScreenConfig.horizontalPadding(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }

    if (_channels.isEmpty) return _emptyState(padding);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _filter,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن قناة...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadChannels,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'تحديث',
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 16 / 10,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, i) => _channelCard(_filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(double padding) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv_off, color: Colors.white38, size: 80),
            const SizedBox(height: 16),
            const Text('لا توجد قنوات',
                style: TextStyle(color: Colors.white54, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('أضف رابط M3U من زر "+"',
                style: TextStyle(color: Colors.white30, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadChannels,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelCard(Channel channel) {
    final isFav = _favorites.contains(channel.url);
    return Focus(
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlayerScreen(url: channel.url, title: channel.name),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    hasFocus ? const Color(0xFF3B82F6) : Colors.transparent,
                width: 3,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 16,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Expanded(
                        child: channel.logo != null &&
                                channel.logo!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: channel.logo!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.live_tv,
                                        color: Colors.white54, size: 40),
                                placeholder: (_, __) => const Icon(
                                    Icons.live_tv,
                                    color: Colors.white24,
                                    size: 40),
                              )
                            : const Icon(Icons.live_tv,
                                color: Colors.white54, size: 40),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    iconSize: 20,
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.white38,
                    ),
                    onPressed: () async {
                      await StorageService.toggleFavorite(channel.url);
                      final favs = await StorageService.loadFavorites();
                      if (mounted) {
                        setState(() => _favorites = favs);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
