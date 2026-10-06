import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/movie_detail.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Channel channel;
  const MovieDetailScreen({super.key, required this.channel});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await StorageService.loadXtreamCreds();
    if (creds == null || widget.channel.id == null) {
      setState(() => _loading = false);
      return;
    }
    final d = await XtreamService.fetchVodInfo(
      host: creds['host']!,
      username: creds['username']!,
      password: creds['password']!,
      vodId: widget.channel.id!,
    );
    if (mounted) {
      setState(() {
        _detail = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: const Color(0xFF111827),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _detail?.name ?? widget.channel.name,
                style: const TextStyle(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if ((_detail?.poster ?? widget.channel.logo) != null)
                    Image.network(
                      _detail?.poster ?? widget.channel.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0A0E1A)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMeta(),
                  const SizedBox(height: 16),
                  if (_detail?.plot != null && _detail!.plot!.isNotEmpty)
                    _buildSection('القصة', _detail!.plot!),
                  if (_detail?.cast != null && _detail!.cast!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSection('طاقم العمل', _detail!.cast!),
                  ],
                  if (_detail?.director != null &&
                      _detail!.director!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSection('المخرج', _detail!.director!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _play,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('مشاهدة الآن',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeta() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_detail?.year != null)
          _badge(Icons.calendar_today, _detail!.year!),
        if (_detail?.duration != null)
          _badge(Icons.access_time, _detail!.duration!),
        if (_detail?.rating != null)
          _badge(Icons.star, _detail!.rating!),
        if (_detail?.genre != null)
          _badge(Icons.local_movies, _detail!.genre!),
      ],
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.6)),
      ],
    );
  }

  void _play() {
    final url = _detail?.streamUrl ?? widget.channel.url;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          url: url,
          title: _detail?.name ?? widget.channel.name,
          logo: _detail?.poster ?? widget.channel.logo,
          isLive: false,
        ),
      ),
    );
  }
}
