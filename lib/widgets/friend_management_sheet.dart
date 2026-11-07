import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/friend_profile.dart';
import '../services/friend_sync_service.dart';
import '../services/share_service.dart';

/// フレンド機能 v2：クラウド自動同期＆マップ共有ボトムシート。
/// 接続設定は不要（開発者の Supabase へ自動接続）。利用者は自分のコードを
/// 渡す／相手のコードを入れるだけでよい。
class FriendManagementSheet extends StatefulWidget {
  final String myFriendCode;
  final String userName;
  final String syncStatusText;
  final List<FriendProfile> friends;
  final Future<void> Function() onSyncMyMap;
  final Future<bool> Function() onReissueCode;
  final Future<void> Function() onRefreshFriends;
  final Future<bool> Function(String code) onAddFriendByCode;
  final Future<bool> Function(String code) onAddSampleFriend;
  final Future<void> Function(String code) onRemoveFriend;
  final ValueChanged<FriendProfile> onSelectFriendMap;
  final VoidCallback onShowAllFriendsMap;

  const FriendManagementSheet({
    super.key,
    required this.myFriendCode,
    required this.userName,
    required this.syncStatusText,
    required this.friends,
    required this.onSyncMyMap,
    required this.onReissueCode,
    required this.onRefreshFriends,
    required this.onAddFriendByCode,
    required this.onAddSampleFriend,
    required this.onRemoveFriend,
    required this.onSelectFriendMap,
    required this.onShowAllFriendsMap,
  });

  @override
  State<FriendManagementSheet> createState() => _FriendManagementSheetState();
}

class _FriendManagementSheetState extends State<FriendManagementSheet> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _friendQuery = '';
  bool _isSyncing = false;
  bool _isAdding = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddCode(String code) async {
    if (code.trim().isEmpty || _isAdding) return;
    setState(() => _isAdding = true);
    try {
      final added = await widget.onAddFriendByCode(code.trim());
      if (added) {
        _codeController.clear();
      }
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

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefreshFriends();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// コード再発行の確認ダイアログ（旧コードは無効になる）。
  Future<void> _confirmReissueCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'フレンドコードを再発行しますか？',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '新しいコードが発行され、今のコードは使えなくなります。\n'
            'すでにコードを渡した相手には、新しいコードを伝え直してください。',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('再発行する'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onReissueCode();
    }
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'フレンド機能 ＆ マップ共有',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '☁️ クラウド自動同期（設定は不要です）',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
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
            const Divider(height: 18),

// 1. 自分のフレンドコード＆同期状態カード
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
                              fontSize: 20,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
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
                              final code = widget.myFriendCode;
                              final inviteText = '🍴 グルメマップで私の常連店マップを共有中！\n'
                                  'フレンドコード：【$code】\n'
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
                  Text(
                    widget.syncStatusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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
                        _isSyncing ? '同期中...' : '今すぐ同期する',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _confirmReissueCode,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'コードを再発行する（旧コードは無効化）',
                        style: TextStyle(fontSize: 11),
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
                      hintText: '例: GM-ABCDE-23456',
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

// サンプル友達（体験用・端末内のみ。実在の利用者ではない）
            const Text(
              '🧪 サンプル友達（体験用・端末内だけの表示です）：',
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
              children: SampleFriends.presets.map((preset) {
                final alreadyAdded =
                    widget.friends.any((f) => f.friendCode == preset.code);
                return ActionChip(
                  avatar: Icon(
                    alreadyAdded
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
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
                    await widget.onAddSampleFriend(preset.code);
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _isRefreshing ? null : _handleRefresh,
                      tooltip: 'フレンドのマップを最新に更新',
                      visualDensity: VisualDensity.compact,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 19),
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
              ],
            ),
            const SizedBox(height: 6),

            // フレンドが増えてきたら名前・コードで絞り込める検索欄
            if (widget.friends.length >= 3) ...[
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _friendQuery = value),
                decoration: InputDecoration(
                  hintText: 'フレンドを検索（名前・コード）',
                  hintStyle:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _friendQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _friendQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],

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
                  'まだフレンドが追加されていません。\n友達のフレンドコードを入力するか、上の「サンプル友達」で体験できます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              )
            else if (FriendProfile.filterByQuery(widget.friends, _friendQuery)
                .isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '「$_friendQuery」に一致するフレンドはいません',
                    style:
                        const TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ),
              )
            else
              ...FriendProfile.filterByQuery(
                FriendProfile.sortedForDisplay(widget.friends),
                _friendQuery,
              ).map((friend) {
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
                      backgroundColor:
                          friend.themeColor.withValues(alpha: 0.15),
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
                        if (friend.isSample) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'サンプル',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
