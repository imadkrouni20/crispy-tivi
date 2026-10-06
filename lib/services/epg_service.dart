import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;

  EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
  });

  bool get isNow =>
      DateTime.now().isAfter(start) && DateTime.now().isBefore(end);

  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class EpgService {
  /// تحميل EPG من رابط XMLTV (متوافق مع Xtream أيضاً)
  static Future<Map<String, List<EpgProgram>>> fetchFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return {};
      final xmlStr = utf8.decode(response.bodyBytes, allowMalformed: true);
      return parseXmltv(xmlStr);
    } catch (e) {
      return {};
    }
  }

  /// رابط XMLTV الافتراضي من Xtream Codes
  static String xtreamEpgUrl(String host, String username, String password) {
    final base = host.replaceAll(RegExp(r'/$'), '');
    return '$base/xmltv.php?username=$username&password=$password';
  }

  static Map<String, List<EpgProgram>> parseXmltv(String xmlStr) {
    final result = <String, List<EpgProgram>>{};
    try {
      final doc = XmlDocument.parse(xmlStr);

      for (final prog in doc.findAllElements('programme')) {
        final channelId = prog.getAttribute('channel') ?? '';
        final start = _parseXmltvDate(prog.getAttribute('start'));
        final stop = _parseXmltvDate(prog.getAttribute('stop'));
        if (start == null || stop == null) continue;

        String title = '';
        String? desc;
        for (final t in prog.findElements('title')) {
          title = t.innerText.trim();
          break;
        }
        for (final d in prog.findElements('desc')) {
          desc = d.innerText.trim();
          break;
        }
        if (title.isEmpty) continue;

        result.putIfAbsent(channelId, () => []).add(EpgProgram(
          channelId: channelId,
          title: title,
          description: desc,
          start: start,
          end: stop,
        ));
      }

      // رتّب كل قناة حسب الوقت
      for (final key in result.keys) {
        result[key]!.sort((a, b) => a.start.compareTo(b.start));
      }
    } catch (_) {}
    return result;
  }

  static DateTime? _parseXmltvDate(String? s) {
    if (s == null || s.length < 14) return null;
    try {
      // صيغة XMLTV: 20241006183000 +0000
      final year = int.parse(s.substring(0, 4));
      final month = int.parse(s.substring(4, 6));
      final day = int.parse(s.substring(6, 8));
      final hour = int.parse(s.substring(8, 10));
      final minute = int.parse(s.substring(10, 12));
      final second = s.length >= 14 ? int.parse(s.substring(12, 14)) : 0;
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// برنامج الآن لقناة معينة
  static EpgProgram? getNow(List<EpgProgram>? programs) {
    if (programs == null || programs.isEmpty) return null;
    final now = DateTime.now();
    for (final p in programs) {
      if (now.isAfter(p.start) && now.isBefore(p.end)) return p;
    }
    return null;
  }

  /// البرامج القادمة
  static List<EpgProgram> getNext(List<EpgProgram>? programs, {int limit = 5}) {
    if (programs == null || programs.isEmpty) return [];
    final now = DateTime.now();
    return programs
        .where((p) => p.end.isAfter(now))
        .take(limit)
        .toList();
  }
}
