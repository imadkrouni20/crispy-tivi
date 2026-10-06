import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/cache_service.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _cache = CacheService();
  final _ctrl = TextEditingController();

  List<Channel> _liveAll = [];
  List<Channel> _vodAll = [];
  List<Channel> _seriesAll = [];

  List<Channel> _liveRes = [];
  List<Channel> _vodRes = [];
  List<Channel> _seriesRes = [];

  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    _liveAll = _cache.get('live') ?? [];
    _vodAll = _cache.get('vod') ?? [];
    _seriesAll = _cache.get('series') ?? [];

    // إذا لم يكن هناك كاش، حمّل من Xtream
    if (_liveAll.isEmpty && _vodAll.isEmpty && _seriesAll.isEmpty) {
      final creds = await StorageService.loadXtreamCreds();
      if (creds != null) {
        try {
          _liveAll = await XtreamService.fetchStreams(
            host: creds['host']!,
            username: creds['username']!,
            password: creds['password']!,
            type: 'live',
          );
          _cache.set('live', _liveAll);
          _vodAll = await XtreamService.fetchStreams(
            host: creds['host']!,
            username: creds['username']!,
            password: creds['password']!,
            type: 'vod',
          );
          _cache.set('vod', _vodAll);
          _seriesAll = await XtreamService.fetchStreams(
            host: creds['host']!,
            username: creds['username']!,
            password: creds['password']!,
            type: 'series',
          );
          _cache.set('series', _seriesAll);
        } catch (_) {}
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() {
        _liveRes = [];
        _vodRes = [];
        _seriesRes = [];
        _searching = false;
      });
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _searching = true;
      _liveRes = _liveAll
          .where((c) => c.name.toLowerCase().contains(lower))
          .take(50)
          .toList();
      _vodRes = _vodAll
          .where((c) => c.name.toLowerCase().contains(lower))
          .take(50)
          .toList();
      _seriesRes = _seriesAll
          .where((c) => c.name.toLowerCase().contains(lower))
          .take(50)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _search,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'ابحث في القنوات والأفلام والمسلسلات...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _ctrl.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  SizedBox(height: 16),
                  Text('جاري تحميل الفهرس...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : !_searching
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search,
                          color: Colors.white24, size: 80),
                      SizedBox(height: 16),
                      Text('اكتب للبحث في المحتوى',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('قنوات • أفلام • مسلسلات',
                          style: TextStyle(
                              color: Colors.white30, fontSize: 13)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_liveRes.isNotEmpty) ...[
                      _header('قنوات مباشرة', _liveRes.length),
                      ..._liveRes.map((c) => _item(c, 'live')),
                      const SizedBox(height: 16),
                    ],
                    if (_vodRes.isNotEmpty) ...[
                      _header('أفلام', _vodRes.length),
                      ..._vodRes.map((c) => _item(c, 'vod')),
                      const SizedBox(height: 16),
                    ],
                    if (_seriesRes.isNotEmpty) ...[
                      _header('مسلسلات', _seriesRes.length),
                      ..._seriesRes.map((c) => _item(c, 'series')),
                    ],
                    if (_liveRes.isEmpty &&
                        _vodRes.isEmpty &&
                        _seriesRes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  color: Colors.white24, size: 60),
                              SizedBox(height: 16),
                              Text('لا توجد نتائج',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _header(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: Color(0xFF3B82F6), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _item(Channel c, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: c.logo != null && c.logo!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: c.logo!,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.movie,
                        color: Colors.white38),
                  ),
                )
              : const Icon(Icons.movie, color: Colors.white38),
        ),
        title: Text(c.name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: c.group != null
            ? Text(c.group!,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white38, size: 14),
        onTap: () => _openItem(c, type),
      ),
    );
  }

  void _openItem(Channel c, String type) {
    if (type == 'live') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            url: c.url,
            title: c.name,
            logo: c.logo,
            isLive: true,
          ),
        ),
      );
    } else if (type == 'vod') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(channel: c),
        ),
      );
    } else if (type == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(channel: c),
        ),
      );
    }
  }
}
