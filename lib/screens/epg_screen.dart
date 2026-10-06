import 'package:flutter/material.dart';
import '../services/epg_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';

class EpgScreen extends StatefulWidget {
  final Map<String, List<EpgProgram>> epgData;
  const EpgScreen({super.key, required this.epgData});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  String? _selectedChannel;

  @override
  Widget build(BuildContext context) {
    if (widget.epgData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Colors.white38, size: 64),
            SizedBox(height: 16),
            Text('لا يوجد دليل برامج متاح',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('EPG غير مدعوم أو لم يُحمّل بعد',
                style: TextStyle(color: Colors.white30, fontSize: 13)),
          ],
        ),
      );
    }

    final channels = widget.epgData.keys.toList();
    final selected = _selectedChannel ?? channels.first;

    return Row(
      children: [
        // قائمة القنوات
        Container(
          width: 200,
          color: const Color(0xFF111827),
          child: ListView.builder(
            itemCount: channels.length,
            itemBuilder: (_, i) {
              final cid = channels[i];
              final isSelected = cid == selected;
              final now = EpgService.getNow(widget.epgData[cid]);
              return Material(
                color: isSelected
                    ? const Color(0xFF3B82F6).withOpacity(0.2)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedChannel = cid),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cid,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (now != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              now.title,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // برامج القناة المختارة
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(selected,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.epgData[selected]?.length ?? 0,
                  itemBuilder: (_, i) {
                    final p = widget.epgData[selected]![i];
                    final isNow = p.isNow;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isNow
                            ? const Color(0xFF3B82F6).withOpacity(0.15)
                            : const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                        border: isNow
                            ? Border.all(
                                color: const Color(0xFF3B82F6), width: 2)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_fmt(p.start)} - ${_fmt(p.end)}',
                                style: TextStyle(
                                  color: isNow
                                      ? const Color(0xFF3B82F6)
                                      : Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isNow) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Text('الآن',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          if (p.description != null &&
                              p.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              p.description!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (isNow) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: p.progress,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor:
                                    const AlwaysStoppedAnimation(
                                        Color(0xFF3B82F6)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
