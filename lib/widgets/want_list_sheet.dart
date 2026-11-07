import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/want_to_visit.dart';
import '../utils/place_match.dart';

/// N1：「行きたい店」リストのボトムシート。
/// 近い順／新しい順の並び替えと、追加元（検索・地図・フレンド）の
/// 絞り込みに対応し、件数が増えても見失わないようにする。
class WantListSheet extends StatefulWidget {
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

  @override
  State<WantListSheet> createState() => _WantListSheetState();
}

enum _WantSort { nearest, newest }

class _WantListSheetState extends State<WantListSheet> {
  WantSource? _sourceFilter; // null = すべて
  _WantSort _sort = _WantSort.nearest;

  double _meters(WantToVisit want) {
    return PlaceMatch.metersBetween(
      widget.baseLatLng.latitude,
      widget.baseLatLng.longitude,
      want.latitude,
      want.longitude,
    );
  }

  String _distanceLabel(WantToVisit want) {
    final meters = _meters(want);
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.wants
        .where((w) => _sourceFilter == null || w.source == _sourceFilter)
        .toList();
    final sorted = [...filtered]..sort((a, b) {
        if (_sort == _WantSort.newest) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return _meters(a).compareTo(_meters(b));
      });

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
                '行きたい店 (${widget.wants.length}件)',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              // 並び替え切替
              SegmentedButton<_WantSort>(
                segments: const [
                  ButtonSegment(value: _WantSort.nearest, label: Text('近い順')),
                  ButtonSegment(value: _WantSort.newest, label: Text('新しい順')),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => setState(() => _sort = s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 追加元フィルタ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(null, 'すべて'),
                _filterChip(WantSource.search, '検索から'),
                _filterChip(WantSource.map, '地図から'),
                _filterChip(WantSource.friend, 'フレンドから'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '訪問して登録すると、このリストから自動で卒業します。',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          if (widget.wants.isEmpty)
            _emptyBox(
              'まだ「行きたい店」がありません。\n店舗検索の結果・地図の長押し・フレンドの店から追加できます。',
            )
          else if (sorted.isEmpty)
            _emptyBox('その条件の「行きたい店」はありません。')
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final want = sorted[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            want.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEFF1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _distanceLabel(want),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00695C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${want.category} • ${want.source.label}'
                      '${want.sourceLabel != null ? '（${want.sourceLabel}さん）' : ''}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () => widget.onTapItem(want),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFECEFF1),
                            foregroundColor: const Color(0xFF37474F),
                          ),
                          onPressed: () => widget.onRegisterAt(want),
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
                          onPressed: () => widget.onRemove(want),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(WantSource? source, String label) {
    final selected = _sourceFilter == source;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        selected: selected,
        onSelected: (_) => setState(() => _sourceFilter = source),
        selectedColor: const Color(0xFFCFD8DC),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}
