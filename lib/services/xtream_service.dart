import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/movie_detail.dart';
import '../models/series_detail.dart';

class XtreamService {
  static String _base(String host) => host.replaceAll(RegExp(r'/$'), '');

  // ==================== قوائم ====================
  static Future<List<Channel>> fetchStreams({
    required String host,
    required String username,
    required String password,
    required String type,
  }) async {
    final base = _base(host);
    final url =
        '$base/player_api.php?username=$username&password=$password&action=get_${type}_streams';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('فشل الاتصال بـ Xtream: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw Exception('رد غير متوقع من Xtream');

    final channels = <Channel>[];

    if (type == 'live') {
      final categories =
          await _fetchCategories(base, username, password, 'live');
      for (final item in data) {
        final m = item as Map;
        final streamId = m['stream_id'];
        final name = m['name'] ?? 'قناة';
        final icon = m['stream_icon'];
        final catId = m['category_id']?.toString();
        final group = categories[catId] ?? 'عام';
        channels.add(Channel(
          name: name.toString(),
          url: '$base/live/$username/$password/$streamId.m3u8',
          logo: icon?.toString(),
          group: group,
          id: streamId?.toString(),
        ));
      }
    } else if (type == 'vod') {
      final categories =
          await _fetchCategories(base, username, password, 'vod');
      for (final item in data) {
        final m = item as Map;
        final streamId = m['stream_id'];
        final name = m['name'] ?? 'فيلم';
        final icon = m['stream_icon'] ?? m['cover'];
        final ext = m['container_extension'] ?? 'mp4';
        final catId = m['category_id']?.toString();
        final group = categories[catId] ?? 'أفلام';
        channels.add(Channel(
          name: name.toString(),
          url: '$base/movie/$username/$password/$streamId.$ext',
          logo: icon?.toString(),
          group: group,
          id: streamId?.toString(),
        ));
      }
    } else if (type == 'series') {
      final categories =
          await _fetchCategories(base, username, password, 'series');
      for (final item in data) {
        final m = item as Map;
        final seriesId = m['series_id'];
        final name = m['name'] ?? 'مسلسل';
        final icon = m['cover'];
        final catId = m['category_id']?.toString();
        final group = categories[catId] ?? 'مسلسلات';
        channels.add(Channel(
          name: name.toString(),
          url: '$base/series/$username/$password/$seriesId',
          logo: icon?.toString(),
          group: group,
          id: seriesId?.toString(),
        ));
      }
    }

    return channels;
  }

  static Future<Map<String, String>> _fetchCategories(
    String base,
    String username,
    String password,
    String type,
  ) async {
    try {
      final url =
          '$base/player_api.php?username=$username&password=$password&action=get_${type}_categories';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return {};
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return {};

      final map = <String, String>{};
      for (final cat in data) {
        final m = cat as Map;
        final id = m['category_id']?.toString();
        final name = m['category_name']?.toString();
        if (id != null && name != null) map[id] = name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ==================== تفاصيل الفيلم ====================
  static Future<MovieDetail?> fetchVodInfo({
    required String host,
    required String username,
    required String password,
    required String vodId,
  }) async {
    try {
      final base = _base(host);
      final url =
          '$base/player_api.php?username=$username&password=$password&action=get_vod_info&vod_id=$vodId';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! Map) return null;
      // 🔑 cast صريح
      final map = Map<String, dynamic>.from(data);
      return MovieDetail.fromJson(map, base, username, password, vodId);
    } catch (e) {
      return null;
    }
  }

  // ==================== تفاصيل المسلسل ====================
  static Future<SeriesDetail?> fetchSeriesInfo({
    required String host,
    required String username,
    required String password,
    required String seriesId,
  }) async {
    try {
      final base = _base(host);
      final url =
          '$base/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! Map) return null;
      // 🔑 cast صريح
      final map = Map<String, dynamic>.from(data);
      return SeriesDetail.fromJson(map, base, username, password);
    } catch (e) {
      return null;
    }
  }

  // ==================== اختبار الاتصال ====================
  static Future<bool> testConnection({
    required String host,
    required String username,
    required String password,
  }) async {
    try {
      final base = _base(host);
      final url = '$base/player_api.php?username=$username&password=$password';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return data is Map && data['user_info'] != null;
    } catch (_) {
      return false;
    }
  }
}
