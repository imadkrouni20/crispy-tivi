import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class StorageService {
  static const _keySources = 'sources';
  static const _keyChannels = 'cached_channels';
  static const _keyFavorites = 'favorites';

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
}
