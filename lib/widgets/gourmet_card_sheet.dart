import 'package:flutter/material.dart';
import '../models/friend_profile.dart';
import '../models/gamification_data.dart';
import '../models/restaurant_record.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

/// ステップ⑥＆⑧：進化版「マイ・グルメ名刺 ＆ 称号コレクション図鑑」画面
class GourmetCardSheet extends StatefulWidget {
  final String initialUserName;
  final String? customTitle;
  final int cardThemeIndex;
  final bool isProMember;
  final List<RestaurantRecord> records;
  final List<FriendProfile> friends;
  final String avatarEmoji;
  final ValueChanged<String> onAvatarChanged;
  final ValueChanged<String> onUserNameChanged;
  final ValueChanged<String?> onCustomTitleChanged;
  final ValueChanged<int> onCardThemeChanged;
  final VoidCallback onOpenPaywall;

  const GourmetCardSheet({
    super.key,
    required this.avatarEmoji,
    required this.onAvatarChanged,
    required this.initialUserName,
    required this.customTitle,
    required this.cardThemeIndex,
    required this.isProMember,
    required this.records,
    required this.friends,
    required this.onUserNameChanged,
    required this.onCustomTitleChanged,
    required this.onCardThemeChanged,
    required this.onOpenPaywall,
  });

  @override
  State<GourmetCardSheet> createState() => _GourmetCardSheetState();
}

class _GourmetCardSheetState extends State<GourmetCardSheet> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  late String _userName;
  late String _avatarEmoji;
  late String? _selectedTitle;
  late int _themeIndex;
  int _activeTab = 0; // 0: グルメ名刺プレビュー, 1: 称号コレクション図鑑
  bool _isSharingImage = false;

  @override
  void initState() {
    super.initState();
    _userName = widget.initialUserName;
    _avatarEmoji = widget.avatarEmoji;
    _selectedTitle = widget.customTitle;
    _themeIndex = widget.cardThemeIndex;
  }

  String get _effectiveTitle {
    if (_selectedTitle != null && _selectedTitle!.isNotEmpty) {
      return _selectedTitle!;
    }
    return ShareService.calculateGourmetTitle(widget.records);
  }

  /// ユーザー名編集ダイアログ
  /// アバター絵文字の選択ダイアログ。
  Future<void> _editAvatar() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'アイコンを選ぶ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emoji in StorageService.avatarChoices)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(emoji),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: emoji == _avatarEmoji
                            ? const Color(0xFFFFECB3)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emoji == _avatarEmoji
                              ? const Color(0xFFFF8F00)
                              : Colors.grey.shade300,
                          width: emoji == _avatarEmoji ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != _avatarEmoji && mounted) {
      setState(() => _avatarEmoji = selected);
      widget.onAvatarChanged(selected);
    }
  }

  void _editUserName() {
    final controller = TextEditingController(text: _userName);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            '名刺のニックネーム変更',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 16,
            decoration: const InputDecoration(
              labelText: 'ニックネーム',
              hintText: '例：ラーメン太郎',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final newName = controller.text.trim().isEmpty
                    ? 'グルメ開拓者'
                    : controller.text.trim();
                setState(() => _userName = newName);
                widget.onUserNameChanged(newName);
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// X（旧Twitter）へテキスト投稿
  Future<void> _handlePostToX() async {
    final text = ShareService.buildGourmetCardShareText(
      userName: _userName,
      records: widget.records,
    );
    final ok = await ShareService.postToX(text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xの起動に失敗しました。標準シェアをお試しください。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 名刺カードを画像化してOSシェアシートを起動
  Future<void> _handleShareCardImage() async {
    if (_isSharingImage) return;
    setState(() => _isSharingImage = true);
    try {
      final text = ShareService.buildGourmetCardShareText(
        userName: _userName,
        records: widget.records,
      );
      await ShareService.captureAndShareCard(
        boundaryKey: _cardBoundaryKey,
        shareText: text,
        fileName: 'gourmet_meishi_card.png',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelInfo = GamificationEngine.calculateLevelInfo(
      records: widget.records,
      friends: widget.friends,
    );
    final badges = GamificationEngine.evaluateBadges(
      records: widget.records,
      friends: widget.friends,
    );
    final unlockedBadges = badges.where((b) => b.isUnlocked).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),

          // ヘッダー
          Row(
            children: [
              const Icon(Icons.badge, color: Color(0xFF546E7A), size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'グルメ名刺 ＆ 称号コレクション',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _editUserName,
                icon: const Icon(Icons.edit, size: 15),
                label: const Text('名前変更', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _editAvatar,
                icon: Text(_avatarEmoji, style: const TextStyle(fontSize: 15)),
                label: const Text('アイコン', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          // タブ切替バー（名刺プレビュー vs 称号図鑑）
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    label: '🪪 グルメ名刺',
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    label:
                        '🏆 称号図鑑 (${unlockedBadges.length}/${badges.length})',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // メインコンテンツ
          Flexible(
            child: SingleChildScrollView(
              child: _activeTab == 0
                  ? _buildCardTab(
                      levelInfo: levelInfo,
                      unlockedBadges: unlockedBadges,
                    )
                  : _buildBadgesTab(badges: badges),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required String label}) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isSelected ? const Color(0xFF263238) : Colors.black54,
          ),
        ),
      ),
    );
  }

  /// タブ1：グルメ名刺プレビュー＆テーマ変更＆SNSシェア
  Widget _buildCardTab({
    required ({
      int level,
      int currentLevelExp,
      int nextLevelExp,
      double progress
    }) levelInfo,
    required List<AchievementBadge> unlockedBadges,
  }) {
    final totalCharges =
        widget.records.fold<int>(0, (sum, item) => sum + item.chargeCount);
    final goldCount = widget.records.where((r) => r.chargeCount >= 3).length;
    final silverCount = widget.records.where((r) => r.chargeCount == 2).length;

    final sortedRecords = [...widget.records]
      ..sort((a, b) => b.chargeCount.compareTo(a.chargeCount));
    final top3 = sortedRecords.take(3).toList();

    // テーマ別カラーパレット（0: ロイヤル黒金, 1: サイバー青, 2: 和風朱雅,
    // 3: 抹茶モダン, 4: 夕焼けサンセット, 5: 深海ネイビー）
    const List<List<Color>> themeGradients = [
      [Color(0xFF1E1E2C), Color(0xFF2D1B1E), Color(0xFF3E1F14)],
      [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      [Color(0xFF4A0E0E), Color(0xFF7B1F1F), Color(0xFF3E1E04)],
      [Color(0xFF1B2A1B), Color(0xFF2E4A2A), Color(0xFF556B2F)],
      [Color(0xFF2D1B4E), Color(0xFF7B2D5B), Color(0xFFE65100)],
      [Color(0xFF0A1628), Color(0xFF10243E), Color(0xFF1B3A5C)],
    ];
    const List<Color> themeAccents = [
      Color(0xFFFFD54F),
      Color(0xFF00E5FF),
      Color(0xFFFFB74D),
      Color(0xFFC5E1A5),
      Color(0xFFFFAB91),
      Color(0xFF82B1FF),
    ];
    final themeIdx = (_themeIndex >= 0 && _themeIndex < themeGradients.length)
        ? _themeIndex
        : 0;
    final List<Color> bgGradient = themeGradients[themeIdx];
    final Color borderAccent = themeAccents[themeIdx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ====== 画像キャプチャ対象：グルメ名刺カード本体 ======
        RepaintBoundary(
          key: _cardBoundaryKey,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradient,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderAccent,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上段：称号バッジ ＆ レベル表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _themeIndex == 1
                                ? const [Color(0xFF00E5FF), Color(0xFF00B0FF)]
                                : const [Color(0xFFFFD700), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _effectiveTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderAccent, width: 1),
                      ),
                      child: Text(
                        'Lv.${levelInfo.level}',
                        style: TextStyle(
                          color: borderAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // アバター ＆ ユーザー名 ＆ PROバッジ
                Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      child: Text(
                        _avatarEmoji,
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (widget.isProMember)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '👑 PRO',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // EXPプログレスバー
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: levelInfo.progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(borderAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EXP ${levelInfo.currentLevelExp}/${levelInfo.nextLevelExp}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 統計3カラム
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCardStat(
                        label: '開拓店舗数',
                        value: '${widget.records.length}店',
                        color: Colors.orangeAccent,
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      _buildCardStat(
                        label: '総チャージ数',
                        value: '⚡$totalCharges回',
                        color: const Color(0xFFFFD700),
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      _buildCardStat(
                        label: '金ピン / 銀ピン',
                        value: '🔥$goldCount / ✨$silverCount',
                        color: Colors.lightBlueAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // マイベスト常連店 TOP3
                Text(
                  '👑 マイベスト常連店 TOP3',
                  style: TextStyle(
                    color: borderAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (top3.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'まだ店舗が登録されていません。街のグルメを記録しよう！',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                else
                  ...List.generate(top3.length, (index) {
                    final r = top3[index];
                    final medal =
                        index == 0 ? '🥇' : (index == 1 ? '🥈' : '🥉');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Text(medal, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            r.priceRange,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: r.chargeCount >= 3
                                  ? const Color(0xFFD50000)
                                  : const Color(0xFF455A64),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '⚡${r.chargeCount}回',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                // 獲得バッジアイコン行
                if (unlockedBadges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '獲得勲章: ',
                        style: TextStyle(color: Colors.white60, fontSize: 10.5),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          children: unlockedBadges.map((b) {
                            return Text(
                              b.emoji,
                              style: const TextStyle(fontSize: 14),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 名刺テーマ切り替えセレクター
        const Text(
          '🎨 名刺デザインテーマ切替',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        // テーマ選択は Expanded を使うため Wrap ではなく 3件×2段の Row で並べる
        // （Wrap の中に Expanded を置くとレイアウト例外でタブ全体が空白になる）
        Row(
          children: [
            _buildThemeChoice(index: 0, label: '👑 ロイヤル黒金', isProOnly: false),
            const SizedBox(width: 8),
            _buildThemeChoice(index: 1, label: '⚡ サイバー青', isProOnly: false),
            const SizedBox(width: 8),
            _buildThemeChoice(index: 2, label: '🌸 和風朱雅', isProOnly: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildThemeChoice(index: 3, label: '🍵 抹茶モダン', isProOnly: false),
            const SizedBox(width: 8),
            _buildThemeChoice(index: 4, label: '🌆 夕焼け', isProOnly: true),
            const SizedBox(width: 8),
            _buildThemeChoice(index: 5, label: '🌊 深海', isProOnly: false),
          ],
        ),

        const SizedBox(height: 18),

        // アクションボタン群
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _handlePostToX,
                  icon: const Text(
                    '𝕏',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  label: const Text(
                    'Xに名刺をポスト',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSharingImage ? null : _handleShareCardImage,
                  icon: _isSharingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share, size: 19),
                  label: const Text(
                    '名刺画像をシェア',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeChoice({
    required int index,
    required String label,
    required bool isProOnly,
  }) {
    final isSelected = _themeIndex == index;
    final locked = isProOnly && !widget.isProMember;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (locked) {
            Navigator.of(context).pop();
            widget.onOpenPaywall();
            return;
          }
          setState(() => _themeIndex = index);
          widget.onCardThemeChanged(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECEFF1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFF546E7A) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (locked) const Icon(Icons.lock, size: 13, color: Colors.amber),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color:
                        isSelected ? const Color(0xFF263238) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// タブ2：全12種類の称号コレクション図鑑 ＆ 二つ名装備
  Widget _buildBadgesTab({required List<AchievementBadge> badges}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '解放した称号をタップすると、あなたの「グルメ名刺」の称号としてセットできます！',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        ...badges.map((badge) {
          final fullTitle = '${badge.emoji} ${badge.title}';
          final isEquipped = _effectiveTitle == fullTitle;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: badge.isUnlocked ? Colors.white : Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isEquipped
                    ? const Color(0xFF37474F)
                    : badge.isUnlocked
                        ? badge.color.withValues(alpha: 0.45)
                        : Colors.grey.shade300,
                width: isEquipped ? 2.0 : 1.2,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: badge.isUnlocked
                    ? badge.color.withValues(alpha: 0.15)
                    : Colors.grey.shade300,
                child: Text(
                  badge.isUnlocked ? badge.emoji : '🔒',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(
                badge.title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: badge.isUnlocked ? Colors.black87 : Colors.grey,
                ),
              ),
              subtitle: Text(
                badge.description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: badge.isUnlocked
                      ? Colors.grey.shade700
                      : Colors.grey.shade500,
                ),
              ),
              trailing: badge.isUnlocked
                  ? FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isEquipped
                            ? const Color(0xFF37474F)
                            : const Color(0xFFECEFF1),
                        foregroundColor:
                            isEquipped ? Colors.white : const Color(0xFF37474F),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedTitle = fullTitle;
                          _activeTab = 0; // 名刺タブに戻って確認
                        });
                        widget.onCustomTitleChanged(fullTitle);
                      },
                      child: Text(
                        isEquipped ? '装備中' : '名刺にセット',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Text(
                      '未解放',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCardStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
