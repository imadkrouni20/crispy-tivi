import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('فشل تحميل M3U: ${response.statusCode}');
    }
    // 🔑 نجبر فك الترميز UTF-8 لتجنب مشكلة Mojibake
    final content = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parseFromString(content);
  }

  static List<Channel> parseFromString(String content) {
    final lines = content.split('\n');
    final channels = <Channel>[];
    String? currentName;
    String? currentLogo;
    String? currentGroup;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        // اسم القناة بعد آخر فاصلة
        final nameMatch = RegExp(r',(.+)$').firstMatch(line);
        currentName = nameMatch?.group(1)?.trim();

        // شعار القناة
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);

        // المجموعة
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        currentGroup = groupMatch?.group(1);
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (currentName != null) {
          channels.add(Channel(
            name: currentName,
            url: line,
            logo: currentLogo,
            group: currentGroup,
          ));
        }
        currentName = null;
        currentLogo = null;
        currentGroup = null;
      }
    }
    return channels;
  }
}
