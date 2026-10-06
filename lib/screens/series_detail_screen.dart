import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/series_detail.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Channel channel;
  const SeriesDetailScreen({super.key, required this.channel});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetail? _detail;
  bool _loading = true;
  int? _selectedSeason;

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
    final d = await XtreamService.fetchSeriesInfo(
      host: creds['host']!,
      username: creds['username']!,
      password: creds['password']!,
      seriesId: widget.channel.id!,
    );
    if (mounted) {
      setState(() {
        _detail = d;
        _selectedSeason = d?.seasons.isNotEmpty == true
            ? d!.seasons.first
            : null;
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
                  const SizedBox(height: 24),
                  if (_detail != null && _detail!.seasons.isNotEmpty) ...[
                    const Text('المواسم',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildSeasonChips(),
                    const SizedBox(height: 16),
                    _buildEpisodesList(),
                  ] else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد حلقات متاحة',
                            style: TextStyle(color: Colors.white54)),
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
        if (_detail?.rating != null)
          _badge(Icons.star, _detail!.rating!),
        if (_detail?.genre != null)
          _badge(Icons.local_movies, _detail!.genre!),
        if (_detail != null && _detail!.seasons.isNotEmpty)
          _badge(Icons.layers,
              '${_detail!.seasons.length} موسم'),
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

  Widget _buildSeasonChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _detail!.seasons.map((s) {
          final selected = _selectedSeason == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text('موسم $s'),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: const Color(0xFF1F2937),
              selectedColor: const Color(0xFF3B82F6),
              onSelected: (_) => setState(() => _selectedSeason = s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEpisodesList() {
    final eps = _detail!.episodes[_selectedSeason] ?? [];
    if (eps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('لا توجد حلقات في هذا الموسم',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    return Column(
      children: eps.map((e) => _episodeTile(e)).toList(),
    );
  }

  Widget _episodeTile(SeriesEpisode e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('${e.episode}',
                style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        title: Text(e.title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: e.duration != null
            ? Text(e.duration!,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11))
            : null,
        trailing: const Icon(Icons.play_circle_fill,
            color: Color(0xFF3B82F6), size: 32),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                url: e.streamUrl,
                title:
                    '${_detail?.name ?? widget.channel.name} - S${e.season}E${e.episode}',
                logo: e.poster ?? _detail?.poster,
                isLive: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
