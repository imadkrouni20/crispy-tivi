import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class StorageService {
  static const _keySources = 'sources';
  static const _keyChannels = 'cached_channels';
  static const _keyFavorites = 'favorites';
  static const _keyXtream = 'xtream_creds';
  static const _keyFavChannels = 'fav_channels_data';

  // ============ المصادر M3U ============
  static Future<void> saveSources(List<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySources, sources);
  }

  static Future<List<String>> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySources) ?? [];
  }

  static Future<void> addSource(String url) async {
    final sources = await loadSources();
    if (!sources.contains(url)) {
      sources.add(url);
      await saveSources(sources);
    }
  }

  static Future<void> removeSource(String url) async {
    final sources = await loadSources();
    sources.remove(url);
    await saveSources(sources);
  }

  // ============ القنوات ============
  static Future<void> saveChannels(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final data = channels
        .map((c) => jsonEncode({
              'name': c.name,
              'url': c.url,
              'logo': c.logo,
              'group': c.group,
            }))
        .toList();
    await prefs.setStringList(_keyChannels, data);
  }

  static Future<List<Channel>> loadChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_keyChannels) ?? [];
    return data.map((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return Channel(
        name: m['name'] as String,
        url: m['url'] as String,
        logo: m['logo'] as String?,
        group: m['group'] as String?,
      );
    }).toList();
  }

  static Future<void> clearChannels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyChannels);
  }

  // ============ المفضلة ============
  static Future<void> toggleFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_keyFavorites) ?? [];
    if (favs.contains(url)) {
      favs.remove(url);
    } else {
      favs.add(url);
    }
    await prefs.setStringList(_keyFavorites, favs);
  }

  static Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFavorites) ?? [];
  }

  // ============ Xtream Codes ============
  static Future<void> saveXtreamCreds({
    required String host,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyXtream,
      jsonEncode({
        'host': host,
        'username': username,
        'password': password,
      }),
    );
  }

  static Future<Map<String, String>?> loadXtreamCreds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyXtream);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      'host': m['host'] as String,
      'username': m['username'] as String,
      'password': m['password'] as String,
    };
  }

  static Future<void> clearXtreamCreds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyXtream);
  }

  // ============ مسح كل شيء ============
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySources);
    await prefs.remove(_keyChannels);
    await prefs.remove(_keyFavorites);
    await prefs.remove(_keyXtream);
    await prefs.remove(_keyFavChannels);
  }
}
