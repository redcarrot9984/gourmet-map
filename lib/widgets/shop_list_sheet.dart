import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/restaurant_record.dart';

/// UI/UX改善：登録した全店舗をランク別・チャージ数順に一覧＆ジャンプできるボトムシート
class ShopListSheet extends StatefulWidget {
  final List<RestaurantRecord> records;
  final ValueChanged<RestaurantRecord> onSelectShop;
  final ValueChanged<RestaurantRecord> onQuickCharge;

  const ShopListSheet({
    super.key,
    required this.records,
    required this.onSelectShop,
    required this.onQuickCharge,
  });

  @override
  State<ShopListSheet> createState() => _ShopListSheetState();
}

class _ShopListSheetState extends State<ShopListSheet> {
  int _rankFilter = 0; // 0: すべて, 3: 金ピン(3回以上), 2: 銀ピン(2回), 1: 銅ピン(1回)

  List<RestaurantRecord> get _filteredRecords {
    final list = widget.records.where((r) {
      if (_rankFilter == 3) return r.chargeCount >= 3;
      if (_rankFilter == 2) return r.chargeCount == 2;
      if (_rankFilter == 1) return r.chargeCount == 1;
      return true;
    }).toList();

    list.sort((a, b) => b.chargeCount.compareTo(a.chargeCount));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
                color: Color(0xFFFF5722),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'マイグルメ図鑑・店舗一覧 (${widget.records.length}店)',
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ランク絞り込みチップ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRankChip(0, 'すべて (${widget.records.length})'),
                const SizedBox(width: 6),
                _buildRankChip(
                  3,
                  '🔥 金ピン (${widget.records.where((r) => r.chargeCount >= 3).length})',
                ),
                const SizedBox(width: 6),
                _buildRankChip(
                  2,
                  '⚡ 銀ピン (${widget.records.where((r) => r.chargeCount == 2).length})',
                ),
                const SizedBox(width: 6),
                _buildRankChip(
                  1,
                  '🍴 銅ピン (${widget.records.where((r) => r.chargeCount == 1).length})',
                ),
              ],
            ),
          ),
          const Divider(height: 18),

          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '該当するお店がまだありません。\n画面下の「＋ 店を登録」から記録してみましょう！',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  final isGold = r.chargeCount >= 3;
                  final isSilver = r.chargeCount == 2;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isGold
                            ? const Color(0xFFFFB300)
                            : isSilver
                                ? const Color(0xFF90A4AE)
                                : Colors.grey.shade300,
                        width: isGold ? 2.0 : 1.2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelectShop(r);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // サムネイルまたはランクアイコン
                            if (r.imageBase64 != null &&
                                r.imageBase64!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(r.imageBase64!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: isGold
                                        ? const [
                                            Color(0xFFFFD700),
                                            Color(0xFFFF6F00)
                                          ]
                                        : isSilver
                                            ? const [
                                                Color(0xFFCFD8DC),
                                                Color(0xFF607D8B)
                                              ]
                                            : const [
                                                Color(0xFFCD7F32),
                                                Color(0xFF8B4513)
                                              ],
                                  ),
                                ),
                                child: Icon(
                                  isGold
                                      ? Icons.local_fire_department
                                      : isSilver
                                          ? Icons.stars_rounded
                                          : Icons.restaurant,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            const SizedBox(width: 12),

                            // 店名・タグ情報
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${r.category} • ${r.priceRange}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (r.goodPoints.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      r.goodPoints.map((t) => '#$t').join(' '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFD84315),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // チャージ回数＆ワンタップチャージ
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isGold
                                        ? const Color(0xFFD50000)
                                        : isSilver
                                            ? const Color(0xFF455A64)
                                            : const Color(0xFF6D4C41),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isGold
                                        ? '🔥 ${r.chargeCount}回'
                                        : '⚡ ${r.chargeCount}回',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onQuickCharge(r);
                                  },
                                  child: const Text(
                                    '＋1チャージ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFF5722),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildRankChip(int value, String label) {
    final selected = _rankFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xFFFF5722),
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (_) => setState(() => _rankFilter = value),
    );
  }
}
