import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/friend_profile.dart';
import '../services/friend_supabase_service.dart';
import '../services/share_service.dart';

/// ステップ⑦：フレンド機能・Supabaseクラウド同期・友達のマップ共有ボトムシート
class FriendManagementSheet extends StatefulWidget {
  final String myFriendCode;
  final String userName;
  final List<FriendProfile> friends;
  final Future<void> Function() onSyncMyMap;
  final Future<void> Function(String code) onAddFriendByCode;
  final Future<void> Function(String code) onRemoveFriend;
  final ValueChanged<FriendProfile> onSelectFriendMap;
  final VoidCallback onShowAllFriendsMap;

  const FriendManagementSheet({
    super.key,
    required this.myFriendCode,
    required this.userName,
    required this.friends,
    required this.onSyncMyMap,
    required this.onAddFriendByCode,
    required this.onRemoveFriend,
    required this.onSelectFriendMap,
    required this.onShowAllFriendsMap,
  });

  @override
  State<FriendManagementSheet> createState() => _FriendManagementSheetState();
}

class _FriendManagementSheetState extends State<FriendManagementSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSyncing = false;
  bool _isAdding = false;

  static const List<({String code, String label})> _presetFriends = [
    (code: 'GM-1029', label: '🍜 メンマ先輩 (GM-1029)'),
    (code: 'GM-4410', label: '☕ カフェ巡り葵 (GM-4410)'),
    (code: 'GM-8831', label: '🥩 肉とスパイスの健 (GM-8831)'),
  ];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleAddCode(String code) async {
    if (code.trim().isEmpty || _isAdding) return;
    setState(() => _isAdding = true);
    try {
      await widget.onAddFriendByCode(code.trim());
      _codeController.clear();
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await widget.onSyncMyMap();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  /// Supabase接続情報（URL / Anon Key）＆ SQL確認ダイアログ
  void _showSupabaseConfigDialog() {
    final urlCtrl =
        TextEditingController(text: FriendSupabaseService.supabaseUrl);
    final keyCtrl =
        TextEditingController(text: FriendSupabaseService.supabaseAnonKey);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Supabase クラウド連携設定',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SupabaseのProject URLとAnon Keyを設定すると、実データベース（shared_mapsテーブル）を介して全国の友達とリアルタイムでマップ共有できます。\n※未設定でもサンプル友達やコード入力でローカル共有テストが可能です。',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Project URL',
                    hintText: 'https://xxxx.supabase.co',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Anon Key',
                    hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text: FriendSupabaseService.supabaseSetupSql,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Supabase SQL Editor用のテーブル作成SQLをコピーしました'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text(
                    'テーブル作成SQLをコピー',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                await FriendSupabaseService().saveSupabaseCredentials(
                  url: urlCtrl.text,
                  anonKey: keyCtrl.text,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        FriendSupabaseService.isCloudConfigured
                            ? '☁️ Supabaseクラウド連携を有効化しました！'
                            : 'デモ共有モードに設定しました',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // ハンドル
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

            // ヘッダー
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFF7B1FA2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'フレンド機能 ＆ マップ共有',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        FriendSupabaseService.isCloudConfigured
                            ? '☁️ Supabaseクラウド接続中'
                            : '⚡ 即時テスト対応（Supabase設定も可）',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: FriendSupabaseService.isCloudConfigured
                              ? Colors.green.shade700
                              : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showSupabaseConfigDialog,
                  tooltip: 'Supabase接続設定',
                  icon: const Icon(Icons.cloud_queue, color: Color(0xFF7B1FA2)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 18),

            // 1. 自分のフレンドコード＆マップ同期カード
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'あなたのフレンドコード',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.myFriendCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.myFriendCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('フレンドコードをコピーしました！'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            tooltip: 'コードをコピー',
                            icon: const Icon(Icons.copy, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () {
                              final inviteText =
                                  '🍴 グルメマップで私の常連店マップを共有中！\n'
                                  'フレンドコード：【${widget.myFriendCode}】\n'
                                  'アプリでコードを入力してマップを見てね！ #グルメマップ';
                              ShareService.shareTextOnly(inviteText);
                            },
                            tooltip: '友達にコードを送る',
                            icon: const Icon(Icons.share, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSyncing ? null : _handleSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(
                        _isSyncing
                            ? '同期中...'
                            : '自分の最新マップをクラウド同期して公開',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. フレンドコードで友達を追加
            const Text(
              'フレンドコードを入力して友達のマップを追加',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: '例: GM-1029',
                      prefixIcon: const Icon(Icons.person_search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isAdding
                        ? null
                        : () => _handleAddCode(_codeController.text),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text(
                      '追加',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ワンタップで試せるプリセット友達チップ
            const Text(
              '✨ ワンタップで試せるサンプル友達（現在地周辺にピンが出現します）：',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _presetFriends.map((preset) {
                final alreadyAdded =
                    widget.friends.any((f) => f.friendCode == preset.code);
                return ActionChip(
                  avatar: Icon(
                    alreadyAdded ? Icons.check_circle : Icons.add_circle_outline,
                    size: 16,
                    color: alreadyAdded
                        ? Colors.green.shade700
                        : const Color(0xFF7B1FA2),
                  ),
                  label: Text(
                    preset.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: alreadyAdded
                          ? Colors.green.shade800
                          : const Color(0xFF4A148C),
                    ),
                  ),
                  backgroundColor: alreadyAdded
                      ? Colors.green.shade50
                      : Colors.purple.shade50,
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await _handleAddCode(preset.code);
                    if (mounted) {
                      nav.pop();
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 3. 追加済みフレンド一覧
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共有中のフレンド一覧 (${widget.friends.length}人)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                if (widget.friends.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onShowAllFriendsMap();
                    },
                    icon: const Icon(Icons.layers, size: 16),
                    label: const Text(
                      '全員のピンを重ねて見る',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            if (widget.friends.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'まだフレンドが追加されていません。\n上の「サンプル友達」をタップすると、すぐに友達のマップ共有を体験できます！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              )
            else
              ...widget.friends.map((friend) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: friend.themeColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: friend.themeColor.withValues(alpha: 0.15),
                      child: Text(
                        friend.avatarEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            friend.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: friend.themeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            friend.friendCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${friend.title} • ${friend.records.length}店舗 (⚡${friend.totalCharges}回)',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                friend.themeColor.withValues(alpha: 0.12),
                            foregroundColor: friend.themeColor,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onSelectFriendMap(friend);
                          },
                          child: const Text(
                            'マップ表示',
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
                          tooltip: '解除',
                          onPressed: () =>
                              widget.onRemoveFriend(friend.friendCode),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
