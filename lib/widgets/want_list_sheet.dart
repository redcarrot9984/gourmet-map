import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/want_to_visit.dart';
import '../utils/place_match.dart';

/// N1：「行きたい店」リストのボトムシート。
/// 現在地（または地図中心）から近い順に表示する。
class WantListSheet extends StatelessWidget {
  final List<WantToVisit> wants;
  final LatLng baseLatLng;
  final ValueChanged<WantToVisit> onTapItem;
  final ValueChanged<WantToVisit> onRegisterAt;
  final ValueChanged<WantToVisit> onRemove;

  const WantListSheet({
    super.key,
    required this.wants,
    required this.baseLatLng,
    required this.onTapItem,
    required this.onRegisterAt,
    required this.onRemove,
  });

  String _distanceLabel(WantToVisit want) {
    final meters = PlaceMatch.metersBetween(
      baseLatLng.latitude,
      baseLatLng.longitude,
      want.latitude,
      want.longitude,
    );
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...wants]..sort(
        (a, b) => PlaceMatch.metersBetween(
          baseLatLng.latitude,
          baseLatLng.longitude,
          a.latitude,
          a.longitude,
        ).compareTo(
          PlaceMatch.metersBetween(
            baseLatLng.latitude,
            baseLatLng.longitude,
            b.latitude,
            b.longitude,
          ),
        ),
      );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bookmark, color: Color(0xFF00897B), size: 22),
              const SizedBox(width: 8),
              Text(
                '行きたい店リスト (${sorted.length}件)',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '近い順に表示しています。訪問して登録すると、このリストから自動で卒業します。',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'まだ「行きたい店」がありません。\n店舗検索の結果・地図の長押し・フレンドの店から追加できます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final want = sorted[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.teal.shade100, width: 1.2),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.bookmark,
                          color: Color(0xFF00897B),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        want.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        '${want.category} • ${_distanceLabel(want)} • ${want.source.label}'
                        '${want.sourceLabel != null ? '（${want.sourceLabel}さん）' : ''}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => onTapItem(want),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFFE0F2F1),
                              foregroundColor: const Color(0xFF00695C),
                            ),
                            onPressed: () => onRegisterAt(want),
                            child: const Text(
                              '行って登録',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            tooltip: '削除',
                            onPressed: () => onRemove(want),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
