import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/restaurant_record.dart';

/// ステップ⑤：10秒〜1分以内で終わる爆速登録ボトムシート
class QuickRegisterSheet extends StatefulWidget {
  final List<NearbyCandidate> candidates;
  final List<RestaurantRecord> existingRecords;
  final LatLng currentLatLng;
  final Future<void> Function({
    required String id,
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required String priceRange,
    required List<String> goodPoints,
    String? imagePath,
    String? imageBase64,
  }) onSubmit;

  /// N1：候補を「行きたいリスト」へ追加する（任意）。
  final Future<bool> Function(NearbyCandidate candidate)? onAddToWantList;

  const QuickRegisterSheet({
    super.key,
    required this.candidates,
    required this.existingRecords,
    required this.currentLatLng,
    required this.onSubmit,
    this.onAddToWantList,
  });

  @override
  State<QuickRegisterSheet> createState() => _QuickRegisterSheetState();
}

class _QuickRegisterSheetState extends State<QuickRegisterSheet> {
  static const List<String> _priceOptions = [
    '〜1,000円',
    '1,000〜2,000円',
    '2,000円〜',
  ];

  static const List<String> _goodPointOptions = [
    '神コスパ',
    '味が最高',
    '提供が早い',
    '1人でも入りやすい',
    'ボリューム満点',
    '雰囲気◎',
  ];

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _customNameController = TextEditingController();

  late int _selectedCandidateIndex;
  bool _useCustomName = false;
  String _selectedPrice = '〜1,000円';
  final Set<String> _selectedGoodPoints = {'味が最高'};

  String? _imagePath;
  String? _imageBase64;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  // N1：このシート内で「行きたい」に追加済みの候補ID
  final Set<String> _wantAddedIds = {};

  @override
  void initState() {
    super.initState();
    // ステップ④で取得した現在地周辺の店名候補の先頭を自動で選択
    _selectedCandidateIndex = 0;
    _syncExistingTagsIfAny();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  /// 選択中の店名を取得
  String get _currentShopName {
    if (_useCustomName) {
      final text = _customNameController.text.trim();
      return text.isEmpty ? 'マイベスト飲食店' : text;
    }
    if (widget.candidates.isNotEmpty &&
        _selectedCandidateIndex < widget.candidates.length) {
      return widget.candidates[_selectedCandidateIndex].name;
    }
    return '周辺の飲食店';
  }

  /// 選択中の店舗がすでに登録済みか検索
  RestaurantRecord? get _matchedExistingRecord {
    final targetName = _currentShopName.trim();
    for (final r in widget.existingRecords) {
      if (r.name.trim() == targetName) {
        return r;
      }
      if (!_useCustomName &&
          widget.candidates.isNotEmpty &&
          r.id == widget.candidates[_selectedCandidateIndex].id) {
        return r;
      }
    }
    return null;
  }

  void _syncExistingTagsIfAny() {
    final existing = _matchedExistingRecord;
    if (existing != null) {
      _selectedPrice = existing.priceRange;
      if (existing.goodPoints.isNotEmpty) {
        _selectedGoodPoints
          ..clear()
          ..addAll(existing.goodPoints);
      }
    }
  }

  /// カメラまたはギャラリーから料理写真を取得
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 70,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _imagePath = picked.path;
        _imageBytes = bytes;
        _imageBase64 = base64Str;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('写真の取得に失敗しました（カメラ権限等をご確認ください）: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      String id;
      String name;
      String category;
      double lat;
      double lng;

      if (!_useCustomName &&
          widget.candidates.isNotEmpty &&
          _selectedCandidateIndex < widget.candidates.length) {
        final c = widget.candidates[_selectedCandidateIndex];
        id = c.id;
        name = c.name;
        category = c.category;
        lat = c.latitude;
        lng = c.longitude;
      } else {
        name = _currentShopName;
        id = 'custom_${name.hashCode}';
        category = '🍴 飲食店';
        lat = widget.currentLatLng.latitude;
        lng = widget.currentLatLng.longitude;
      }

      await widget.onSubmit(
        id: id,
        name: name,
        category: category,
        latitude: lat,
        longitude: lng,
        priceRange: _selectedPrice,
        goodPoints: _selectedGoodPoints.toList(),
        imagePath: _imagePath,
        imageBase64: _imageBase64,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _matchedExistingRecord;
    final nextCount = (existing?.chargeCount ?? 0) + 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ドラッグハンドル
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

            // ヘッダータイトル
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Color(0xFFFF5722),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '爆速グルメ記録 ＆ チャージ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '周辺の店舗候補を自動検出しました！ワンタップで記録完了',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 20),

            // 1. 周辺店舗候補の自動選択セクション（ステップ④連携）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '① 現在地周辺の店名候補（自動選択）',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _useCustomName = !_useCustomName;
                    });
                  },
                  icon: Icon(
                    _useCustomName ? Icons.list : Icons.edit,
                    size: 15,
                  ),
                  label: Text(
                    _useCustomName ? '候補リストから選ぶ' : '店名を手入力',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_useCustomName)
              TextField(
                controller: _customNameController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '店名を入力（例：ラーメン二郎、スターバックス）',
                  prefixIcon: const Icon(Icons.storefront),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(widget.candidates.length, (index) {
                  final candidate = widget.candidates[index];
                  final isSelected = _selectedCandidateIndex == index;
                  final savedRecord = widget.existingRecords
                      .where((r) =>
                          r.name.trim() == candidate.name.trim() ||
                          r.id == candidate.id)
                      .firstOrNull;
                  final currentCount = savedRecord?.chargeCount ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedCandidateIndex = index;
                          _syncExistingTagsIfAny();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFF3E0)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF5722)
                                : Colors.grey.shade300,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? const Color(0xFFFF5722)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          candidate.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? const Color(0xFFD84315)
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          '${candidate.category} • ${candidate.distanceMeters}m',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // チャージ状態バッジ
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: currentCount == 0
                                    ? Colors.brown.shade100
                                    : currentCount == 1
                                        ? Colors.blueGrey.shade100
                                        : Colors.amber.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                currentCount == 0
                                    ? '初訪問 (銅へ)'
                                    : currentCount == 1
                                        ? '現在1回 → 銀へ⚡'
                                        : '現在$currentCount回 → 金🔥',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: currentCount == 0
                                      ? Colors.brown.shade800
                                      : currentCount == 1
                                          ? Colors.blueGrey.shade900
                                          : Colors.deepOrange.shade900,
                                ),
                              ),
                            ),
                            // N1：未登録の候補は「行きたい」に追加できる
                            if (widget.onAddToWantList != null &&
                                currentCount == 0)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: _wantAddedIds.contains(candidate.id)
                                    ? '行きたいリストに追加済み'
                                    : '行きたいリストに追加',
                                icon: Icon(
                                  _wantAddedIds.contains(candidate.id)
                                      ? Icons.bookmark
                                      : Icons.bookmark_add_outlined,
                                  color: const Color(0xFF00897B),
                                  size: 21,
                                ),
                                onPressed: () async {
                                  final added =
                                      await widget.onAddToWantList!(candidate);
                                  if (added && mounted) {
                                    setState(() {
                                      _wantAddedIds.add(candidate.id);
                                    });
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

            const SizedBox(height: 12),

            // 2. 料理の写真（カメラ撮影 or ギャラリー選択）
            const Text(
              '② 料理の写真（カメラ撮影 / アルバム）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            if (_imageBytes != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _imageBytes = null;
                            _imagePath = null;
                            _imageBase64 = null;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                '撮り直す',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFFFF5722),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt,
                          color: Color(0xFFFF5722)),
                      label: const Text(
                        'カメラで撮影',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5722),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text(
                        'アルバムから選択',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // 3. 価格帯タグ（ワンタップ選択）
            const Text(
              '③ 価格帯タグ（ワンタップ）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: _priceOptions.map((price) {
                final isSelected = _selectedPrice == price;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          price,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF5722),
                      backgroundColor: Colors.grey.shade100,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedPrice = price);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 4. 良かった点タグ（複数タップ選択）
            const Text(
              '④ 良かった点タグ（複数選択OK）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _goodPointOptions.map((tag) {
                final isSelected = _selectedGoodPoints.contains(tag);
                return FilterChip(
                  label: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? const Color(0xFFD84315) : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFCCBC),
                  checkmarkColor: const Color(0xFFD84315),
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (checked) {
                    setState(() {
                      if (checked) {
                        _selectedGoodPoints.add(tag);
                      } else {
                        _selectedGoodPoints.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // 5. 登録＆チャージ実行ボタン
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: nextCount >= 3
                      ? const Color(0xFFFF6F00) // 金＋炎カラー
                      : nextCount == 2
                          ? const Color(0xFF455A64) // 銀カラー
                          : const Color(0xFFFF5722), // 通常オレンジ
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: Icon(
                  nextCount >= 3
                      ? Icons.local_fire_department
                      : nextCount == 2
                          ? Icons.bolt
                          : Icons.add_location_alt,
                  size: 24,
                ),
                label: Text(
                  nextCount == 1
                      ? '「$_currentShopName」を登録（1回目・銅ピン）'
                      : nextCount == 2
                          ? '⚡ チャージ+1！（2回目・銀ピンに進化！）'
                          : '🔥 チャージ+1！（$nextCount回目・金＋炎ピン！）',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
