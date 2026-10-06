import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/watch_progress_service.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? logo;
  final bool isLive;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.logo,
    this.isLive = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _loading = true;
  String? _error;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _saveTimer;
  final List<StreamSubscription> _subs = [];
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _controller = VideoController(_player);

    _initPlayer();
    _setupListeners();

    if (!widget.isLive) {
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _saveProgress();
      });
    }
  }

  void _setupListeners() {
    _subs.add(_player.stream.error.listen((event) {
      if (mounted && event.isNotEmpty) {
        setState(() {
          _error = event;
          _loading = false;
        });
      }
    }));

    _subs.add(_player.stream.playing.listen((playing) {
      if (playing && mounted && _loading) {
        setState(() => _loading = false);
      }
    }));
  }

  Future<void> _initPlayer() async {
    try {
      await _player.open(Media(widget.url), play: true);

      if (!widget.isLive) {
        final progress = await WatchProgressService.get(widget.url);
        if (progress != null && progress.isWatchable) {
          await _player.seek(
              Duration(milliseconds: progress.positionMs));
          if (mounted) {
            setState(() => _resumed = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFF1F2937),
                content: Text(
                  'استئناف من ${_fmt(Duration(milliseconds: progress.positionMs))}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        Future.delayed(const Duration(seconds: 12), () {
          if (mounted && _loading) {
            setState(() {
              _error = 'لم يبدأ التشغيل خلال 12 ثانية';
              _loading = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    if (widget.isLive) return;
    final pos = _player.state.position;
    final dur = _player.state.duration;
    if (dur.inMilliseconds > 0) {
      await WatchProgressService.save(widget.url, pos, dur);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  @override
  void dispose() {
    _saveProgress();
    for (final s in _subs) s.cancel();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(child: _buildBody()),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _buildOverlay(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.black87],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_resumed)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('متابعة',
                        style:
                            TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                StreamBuilder<bool>(
                  stream: _player.stream.buffering,
                  initialData: _player.state.buffering,
                  builder: (_, snap) {
                    if (snap.data == true) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Color(0xFF3B82F6),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(width: 42);
                  },
                ),
              ],
            ),
            const Spacer(),
            if (_error == null) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('تعذر تشغيل هذه القناة',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('رجوع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _initPlayer();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return Stack(
        children: [
          if (widget.logo != null && widget.logo!.isNotEmpty)
            Opacity(
              opacity: 0.25,
              child: Center(
                child: Image.network(
                  widget.logo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF3B82F6)),
                SizedBox(height: 16),
                Text('جاري التحميل...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      );
    }

    return Video(
      controller: _controller,
      controls: NoVideoControls,
      fill: Colors.black,
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isLive)
            StreamBuilder<Duration>(
              stream: _player.stream.position,
              initialData: _player.state.position,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.stream.duration,
                  initialData: _player.state.duration,
                  builder: (_, durSnap) {
                    final dur = durSnap.data ?? Duration.zero;
                    final total = dur.inMilliseconds;
                    final current = pos.inMilliseconds;
                    final progress = total > 0
                        ? (current / total).clamp(0.0, 1.0)
                        : 0.0;

                    return Row(
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: progress,
                            activeColor: const Color(0xFF3B82F6),
                            inactiveColor: Colors.white24,
                            onChanged: total > 0
                                ? (v) {
                                    final ms = (v * total).toInt();
                                    _player.seek(
                                        Duration(milliseconds: ms));
                                  }
                                : null,
                          ),
                        ),
                        Text(_fmt(dur),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    );
                  },
                );
              },
            )
          else
            const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: _player.state.playing,
                builder: (_, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      playing ? _player.pause() : _player.play();
                      _startHideTimer();
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _player.seek(Duration.zero);
                  _startHideTimer();
                },
                tooltip: 'إعادة من البداية',
              ),
              const SizedBox(width: 16),
              // 🔧 إصلاح: استخدام Tracks.video بدل List<VideoTrack>
              StreamBuilder<Tracks>(
                stream: _player.stream.tracks,
                initialData: _player.state.tracks,
                builder: (_, snap) {
                  final tracks = snap.data?.video ?? <VideoTrack>[];
                  if (tracks.length < 2) return const SizedBox(width: 36);
                  return IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.hd, color: Colors.white),
                    onPressed: () => _showQualitySheet(tracks),
                    tooltip: 'الجودة',
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () async {
                  if (MediaQuery.of(context).orientation ==
                      Orientation.landscape) {
                    await SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                  } else {
                    await SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualitySheet(List<VideoTrack> tracks) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('اختر الجودة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          ...tracks.map((t) {
            final title = t.title ?? t.id ?? 'Auto';
            return ListTile(
              title: Text(title,
                  style: const TextStyle(color: Colors.white)),
              trailing: _player.state.track.video == t
                  ? const Icon(Icons.check, color: Color(0xFF3B82F6))
                  : null,
              onTap: () {
                _player.setVideoTrack(t);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    if (d == Duration.zero) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
