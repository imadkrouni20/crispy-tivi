import 'package:shared_preferences/shared_preferences.dart';

class WatchProgress {
  final int positionMs;
  final int durationMs;
  final DateTime lastWatch;

  WatchProgress({
    required this.positionMs,
    required this.durationMs,
    required this.lastWatch,
  });

  double get percent =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0;

  bool get isFinished => percent > 0.95;
  bool get isWatchable => percent > 0.02 && percent < 0.95;
}

class WatchProgressService {
  static const _prefix = 'watch_';

  static String _key(String url) => '$_prefix${url.hashCode}';

  static Future<void> save(String url, Duration position, Duration duration) async {
    if (duration.inMilliseconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(url),
      '${position.inMilliseconds}|${duration.inMilliseconds}|${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<WatchProgress?> get(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(url));
    if (raw == null) return null;
    try {
      final parts = raw.split('|');
      return WatchProgress(
        positionMs: int.parse(parts[0]),
        durationMs: int.parse(parts[1]),
        lastWatch:
            DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2])),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(url));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
