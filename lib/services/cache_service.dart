import '../models/channel.dart';
import '../services/epg_service.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  final Map<String, List<Channel>> _cache = {};
  final Set<String> _loadingKeys = {};
  final Map<String, DateTime> _lastUpdate = {};

  // EPG
  final Map<String, Map<String, List<EpgProgram>>> _epgCache = {};
  final Map<String, DateTime> _epgUpdate = {};

  bool has(String key) => _cache.containsKey(key);

  bool isValid(String key) {
    final t = _lastUpdate[key];
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < 30;
  }

  bool isLoading(String key) => _loadingKeys.contains(key);
  void startLoading(String key) => _loadingKeys.add(key);
  void stopLoading(String key) => _loadingKeys.remove(key);

  List<Channel>? get(String key) => _cache[key];

  void set(String key, List<Channel> data) {
    _cache[key] = data;
    _lastUpdate[key] = DateTime.now();
  }

  void invalidate(String key) {
    _cache.remove(key);
    _lastUpdate.remove(key);
  }

  void clear() {
    _cache.clear();
    _lastUpdate.clear();
    _loadingKeys.clear();
    _epgCache.clear();
    _epgUpdate.clear();
  }

  // ============ EPG ============
  bool hasEpg(String key) => _epgCache.containsKey(key);

  Map<String, List<EpgProgram>>? getEpg(String key) => _epgCache[key];

  void setEpg(String key, Map<String, List<EpgProgram>> data) {
    _epgCache[key] = data;
    _epgUpdate[key] = DateTime.now();
  }

  void invalidateEpg(String key) {
    _epgCache.remove(key);
    _epgUpdate.remove(key);
  }
}
