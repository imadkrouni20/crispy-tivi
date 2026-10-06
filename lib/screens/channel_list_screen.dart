import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/m3u_parser.dart';
import '../services/xtream_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import '../config/breakpoints.dart';
import 'player_screen.dart';

class ChannelListScreen extends StatefulWidget {
  final bool forceRefresh;
  final bool favoritesOnly;
  final String? contentType; // null | 'live' | 'vod' | 'series'

  const ChannelListScreen({
    super.key,
    this.forceRefresh = false,
    this.favoritesOnly = false,
    this.contentType,
  });

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  final _cache = CacheService();
  List<Channel> _channels = [];
  List<Channel> _filtered = [];
  List<String> _groups = [];
  bool _loading = true;
  List<String> _favorites = [];
  String _selectedGroup = 'الكل';
  final _searchController = TextEditingController();

  String get _cacheKey => widget.favoritesOnly
      ? 'favorites'
      : (widget.contentType ?? 'm3u');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // 1. إذا كان لدينا كاش صالح ولم يُطلب refresh → استخدمه فوراً
    if (!widget.forceRefresh &&
        _cache.has(_cacheKey) &&
        _cache.isValid(_cacheKey)) {
      _favorites = await StorageService.loadFavorites();
      final cached = _cache.get(_cacheKey) ?? [];
      _applyCacheData(cached);
      return;
    }

    // 2. وإلا حمّل من الشبكة
    await _loadChannels(force: widget.forceRefresh);
  }

  void _applyCacheData(List<Channel> data) {
    // استخرج المجموعات
    final groupsSet = <String>{};
    for (final c in data) {
      if (c.group != null && c.group!.isNotEmpty) groupsSet.add(c.group!);
    }
    if (!mounted) return;
    setState(() {
      _channels = data;
      _groups = groupsSet.toList()..sort();
      _filtered = data;
      _loading = false;
    });
  }

  Future<void> _loadChannels({bool force = false}) async {
    setState(() => _loading = true);
    _favorites = await StorageService.loadFavorites();
    _cache.startLoading(_cacheKey);

    var channels = <Channel>[];

    if (widget.favoritesOnly) {
      // المفضلة: اجلب من كل المصادر (live + m3u)
      final all = <Channel>[];
      final m3uCache = _cache.get('m3u') ?? await StorageService.loadChannels();
      all.addAll(m3uCache);
      for (final t in ['live', 'vod', 'series']) {
        final c = _cache.get(t);
        if (c != null) all.addAll(c);
      }
      // إذا لم يوجد كاش إطلاقاً، حمّل من M3U
      if (all.isEmpty) {
        all.addAll(await StorageService.loadChannels());
      }
      channels =
          all.where((c) => _favorites.contains(c.url)).toList();
      _cache.set(_cacheKey, channels);
    } else if (widget.contentType != null) {
      // live / vod / series من Xtream
      final creds = await StorageService.loadXtreamCreds();
      if (creds != null) {
        try {
          channels = await XtreamService.fetchStreams(
            host: creds['host']!,
            username: creds['username']!,
            password: creds['password']!,
            type: widget.contentType!,
          );
          _cache.set(_cacheKey, channels);
        } catch (e) {
          debugPrint('Xtream error: $e');
          channels = _cache.get(_cacheKey) ?? [];
        }
      } else {
        // لا يوجد Xtream → استخدم M3U إذا كان contentType = live
        if (widget.contentType == 'live') {
          channels = await _loadM3U();
          _cache.set(_cacheKey, channels);
        }
      }
    } else {
      // M3U عادي
      channels = await _loadM3U();
      _cache.set(_cacheKey, channels);
    }

    _cache.stopLoading(_cacheKey);

    // استخرج المجموعات
    final groupsSet = <String>{};
    for (final c in channels) {
      if (c.group != null && c.group!.isNotEmpty) groupsSet.add(c.group!);
    }

    if (!mounted) return;
    setState(() {
      _channels = channels;
      _groups = groupsSet.toList()..sort();
      _filtered = channels;
      _loading = false;
    });
  }

  Future<List<Channel>> _loadM3U() async {
    final cached = _cache.get('m3u');
    if (cached != null && cached.isNotEmpty && !widget.forceRefresh) {
      return cached;
    }

    var channels = await StorageService.loadChannels();

    if (channels.isEmpty || widget.forceRefresh) {
      final sources = await StorageService.loadSources();
      if (sources.isNotEmpty) {
        final all = <Channel>[];
        for (final src in sources) {
          try {
            final parsed = await M3UParser.parseFromUrl(src);
            all.addAll(parsed);
          } catch (e) {
            debugPrint('خطأ M3U $src: $e');
          }
        }
        channels = all;
        await StorageService.saveChannels(channels);
      }
    }
    return channels;
  }

  Future<void> _refresh() async {
    _cache.invalidate(_cacheKey);
    await _loadChannels(force: true);
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _channels.where((c) {
        final matchesGroup =
            _selectedGroup == 'الكل' || c.group == _selectedGroup;
        final matchesSearch = q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            (c.group?.toLowerCase().contains(q) ?? false);
        return matchesGroup && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = ScreenConfig.horizontalPadding(context);
    final screen = ScreenConfig.of(context);
    final showSidebar =
        screen == ScreenType.tv || screen == ScreenType.desktop;

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text('جاري التحميل...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_channels.isEmpty) return _emptyState(padding);

    final content = Column(
      children: [
        _buildSearchBar(padding, context),
        _buildCounters(padding),
        if (!showSidebar) _buildGroupChips(),
        const SizedBox(height: 4),
        Expanded(child: _buildGrid(padding)),
      ],
    );

    if (showSidebar) {
      return Row(
        children: [
          _buildGroupSidebar(),
          Expanded(child: content),
        ],
      );
    }
    return content;
  }

  Widget _buildSearchBar(double padding, BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final vPad = isLandscape ? 6.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, vPad, padding, vPad),
      child: SizedBox(
        height: isLandscape ? 40 : 52,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isLandscape ? 13 : 15),
                decoration: InputDecoration(
                  hintText: 'ابحث...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.white54, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          iconSize: 18,
                          icon: const Icon(Icons.clear,
                              color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1F2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 40,
              width: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _refresh,
                icon: const Icon(Icons.refresh,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounters(double padding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: [
          Text(
            '${_filtered.length} ${widget.favoritesOnly ? "مفضلة" : "عنصر"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (_selectedGroup != 'الكل') ...[
            const Text(' • ',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text(
              _selectedGroup,
              style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: [
          _chip('الكل', Icons.apps),
          ..._groups.map((g) => _chip(g, Icons.folder)),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    final selected = _selectedGroup == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon,
            size: 14, color: selected ? Colors.white : Colors.white70),
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(0xFF1F2937),
        selectedColor: const Color(0xFF3B82F6),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onSelected: (_) {
          setState(() => _selectedGroup = label);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildGroupSidebar() {
    return Container(
      width: 180,
      color: const Color(0xFF111827),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('المجموعات',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                _sidebarItem('الكل', _channels.length, Icons.apps),
                ..._groups.map((g) {
                  final count = _channels.where((c) => c.group == g).length;
                  return _sidebarItem(g, count, Icons.folder);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(String label, int count, IconData icon) {
    final selected = _selectedGroup == label;
    return Material(
      color: selected
          ? const Color(0xFF3B82F6).withOpacity(0.2)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedGroup = label);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected
                    ? const Color(0xFF3B82F6)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? const Color(0xFF3B82F6) : Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text('$count',
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF3B82F6)
                        : Colors.white38,
                    fontSize: 11,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(double padding) {
    final cols = ScreenConfig.gridColumns(context);
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 10,
      ),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _channelCard(_filtered[i]),
    );
  }

  Widget _emptyState(double padding) {
    final isFav = widget.favoritesOnly;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isFav ? Icons.favorite_border : Icons.tv_off,
                color: Colors.white38, size: 80),
            const SizedBox(height: 16),
            Text(isFav ? 'لا توجد قنوات مفضلة' : 'لا توجد قنوات',
                style: const TextStyle(color: Colors.white54, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              isFav
                  ? 'اضغط على ❤️ في أي قناة لإضافتها هنا'
                  : 'أضف رابط M3U أو Xtream من زر "+"',
              style: const TextStyle(color: Colors.white30, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  PlayerScreen(url: channel.url, title: channel.name, logo: channel.logo),
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
                      // حدّث كاش المفضلة
                      _cache.invalidate('favorites');
                      if (!mounted) return;
                      setState(() => _favorites = favs);

                      if (widget.favoritesOnly &&
                          !favs.contains(channel.url)) {
                        setState(() {
                          _channels
                              .removeWhere((c) => c.url == channel.url);
                        });
                        _applyFilters();
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(milliseconds: 700),
                          backgroundColor: const Color(0xFF1F2937),
                          content: Text(
                            favs.contains(channel.url)
                                ? 'أُضيفت إلى المفضلة ❤️'
                                : 'أُزيلت من المفضلة',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
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
