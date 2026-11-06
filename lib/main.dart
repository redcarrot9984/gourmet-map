import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'models/friend_profile.dart';
import 'models/want_to_visit.dart';
import 'models/gamification_data.dart';
import 'models/restaurant_record.dart';
import 'services/friend_sync_service.dart';
import 'utils/pin_grouping.dart';
import 'services/restaurant_search_service.dart';
import 'services/share_service.dart';
import 'services/storage_service.dart';
import 'widgets/charge_celebration_dialog.dart';
import 'widgets/cluster_pin_marker.dart';
import 'widgets/merged_pin_marker.dart';
import 'widgets/want_list_sheet.dart';
import 'widgets/want_pin_marker.dart';
import 'widgets/friend_management_sheet.dart';
import 'widgets/friend_pin_marker.dart';
import 'widgets/friend_restaurant_detail_sheet.dart';
import 'widgets/gourmet_card_sheet.dart';
import 'widgets/premium_paywall_sheet.dart';
import 'widgets/quick_register_sheet.dart';
import 'widgets/restaurant_detail_sheet.dart';
import 'widgets/restaurant_pin_marker.dart';
import 'widgets/shop_list_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GourmetMapApp());
}

class GourmetMapApp extends StatelessWidget {
  const GourmetMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'グルメマップ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFFFF9800),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // 初期位置：東京駅（緯度: 35.681236, 経度: 139.767125）
  static const LatLng _tokyoStation = LatLng(35.681236, 139.767125);

  final MapController _mapController = MapController();
  final RestaurantSearchService _searchService = RestaurantSearchService();
  final StorageService _storageService = StorageService();
  final FriendSyncService _friendService = FriendSyncService();

  // 現在地状態
  LatLng? _currentLatLng;
  Position? _currentPosition;
  bool _isLoadingGps = false;
  bool _isSearchingShops = false;
  bool _showGpsDebugDetails = false; // UI/UX改善：GPS座標パネルは必要時のみ開閉可能に
  String _statusMessage = '現在地未取得（初期表示：東京駅）';

  // 登録済み店舗リスト（ステップ⑤）＆ ユーザー設定（ステップ⑥〜⑨）
  List<RestaurantRecord> _records = [];
  String _userName = 'グルメ開拓者';
  String? _customTitle;
  int _cardThemeIndex = 0;
  bool _isProMember = false;

  // ステップ⑦：フレンド機能＆マップフィルター状態
  String _myFriendCode = 'GM-?????-?????';
  List<FriendProfile> _friends = [];
  bool _syncPending = false;
  DateTime? _lastSyncAt;

  // F2：クラスタリング判定用の現在ズーム
  double _currentZoom = 16.0;

  // N1：行きたい店リスト
  List<WantToVisit> _wantList = [];
  MapFilterMode _mapFilterMode = MapFilterMode.allWithFriends;
  String? _selectedFriendCode;

  // リアルタイムGPS監視ストリーム
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLiveTracking = false;

  // 現在地ピン用のアニメーション
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _friendService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// 同期サービス側の状態（未送信フラグ・最終同期時刻）を画面状態へ反映
  void _pullSyncState() {
    _syncPending = _friendService.hasPendingSync;
    _lastSyncAt = _friendService.lastSyncAt;
  }

  String get _syncStatusText {
    if (_syncPending) {
      return '未同期の変更があります（自動で再送します）';
    }
    final last = _lastSyncAt;
    if (last != null) {
      final hh = last.hour.toString().padLeft(2, '0');
      final mm = last.minute.toString().padLeft(2, '0');
      return '最終同期：${last.month}/${last.day} $hh:$mm';
    }
    return 'まだ同期していません';
  }

  // ---------------------------------------------------------------------------
  // N1：行きたいリスト関連
  // ---------------------------------------------------------------------------

  /// 行きたい店を追加し、結果をスナックバーで知らせる（追加できたか返す）。
  Future<bool> _addWant({
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required WantSource source,
    String? sourceLabel,
    bool showFeedback = true,
  }) async {
    final want = WantToVisit(
      id: 'want_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      source: source,
      sourceLabel: sourceLabel,
      createdAt: DateTime.now(),
    );
    final res = await _storageService.addWant(want);
    if (mounted) {
      setState(() => _wantList = res.wants);
      if (showFeedback) {
        final message = switch (res.result) {
          AddWantResult.added => '🔖 「$name」を行きたいリストに追加しました',
          AddWantResult.alreadyInWantList => 'すでに行きたいリストに入っています',
          AddWantResult.alreadyRegistered => 'その店はすでに登録済みです',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return res.result == AddWantResult.added;
  }

  /// 地図の長押し：その場所を行きたい店として登録する。
  Future<void> _handleMapLongPress(LatLng point) async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            '行きたい店として登録',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '店名',
              hintText: '例: 気になるラーメン屋',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('登録する'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final name = nameController.text.trim().isEmpty
        ? '行きたい店'
        : nameController.text.trim();
    await _addWant(
      name: name,
      category: '🍽 その他',
      latitude: point.latitude,
      longitude: point.longitude,
      source: WantSource.map,
    );
  }

  /// 行きたいピンをタップしたときの簡易詳細。
  void _showWantDetail(WantToVisit want) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  const Icon(Icons.bookmark, color: Color(0xFF00897B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      want.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${want.category} • ${want.source.label}'
                '${want.sourceLabel != null ? '（${want.sourceLabel}さん）' : ''}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _registerAtWant(want);
                      },
                      icon: const Icon(Icons.add_location_alt, size: 18),
                      label: const Text(
                        '行って登録する',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final updated = await _storageService.removeWant(want.id);
                      if (mounted) {
                        setState(() => _wantList = updated);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('削除'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 行きたい店の場所へ移動して、登録シートを開く。
  Future<void> _registerAtWant(WantToVisit want) async {
    _mapController.move(want.latLng, 17.2);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      await _openQuickRegisterSheet();
    }
  }

  /// 行きたいリストのシートを開く。
  void _openWantListSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return WantListSheet(
              wants: _wantList,
              baseLatLng: _activeBaseLatLng,
              onTapItem: (want) {
                Navigator.of(ctx).pop();
                _mapController.move(want.latLng, 17.2);
                _showWantDetail(want);
              },
              onRegisterAt: (want) {
                Navigator.of(ctx).pop();
                _registerAtWant(want);
              },
              onRemove: (want) async {
                final updated = await _storageService.removeWant(want.id);
                setState(() => _wantList = updated);
                setSheetState(() {});
              },
            );
          },
        );
      },
    );
  }

  /// 起動時：追加済みフレンドのマップをバックグラウンドで最新化
  Future<void> _refreshFriendsInBackground() async {
    final updated = await _friendService.refreshFriends();
    if (mounted) {
      setState(() => _friends = updated);
    }
  }

  /// ローカル保存された店舗データ・ユーザー設定・フレンド情報を読み込む
  Future<void> _loadInitialData() async {
    final loadedRecords = await _storageService.loadRecords();
    final loadedName = await _storageService.loadUserName();
    final loadedCustomTitle = await _storageService.loadCustomTitle();
    final loadedThemeIdx = await _storageService.loadCardThemeIndex();
    final loadedIsPro = await _storageService.loadIsProMember();
    final loadedWants = await _storageService.loadWantList();
    final friendInit = await _friendService.initialize(
      userName: loadedName,
      records: loadedRecords,
    );

    if (mounted) {
      setState(() {
        _records = loadedRecords;
        _userName = loadedName;
        _customTitle = loadedCustomTitle;
        _cardThemeIndex = loadedThemeIdx;
        _isProMember = loadedIsPro;
        _myFriendCode = friendInit.myCode;
        _friends = friendInit.friends;
        _wantList = loadedWants;
        _pullSyncState();
      });
      unawaited(_refreshFriendsInBackground());
    }
  }

  /// 現在の表示称号
  String get _displayTitle {
    if (_customTitle != null && _customTitle!.isNotEmpty) {
      return _customTitle!;
    }
    return ShareService.calculateGourmetTitle(_records);
  }

  /// 基準となる現在座標を取得（GPS取得済みなら現在地、未取得なら現在のマップ中心座標）
  LatLng get _activeBaseLatLng {
    if (_currentLatLng != null) return _currentLatLng!;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return _tokyoStation;
    }
  }

  /// 現在マップ上に表示すべきフレンドのリストを取得
  List<FriendProfile> get _visibleFriends {
    if (_mapFilterMode == MapFilterMode.mineOnly) {
      return [];
    }
    if (_mapFilterMode == MapFilterMode.singleFriend &&
        _selectedFriendCode != null) {
      return _friends
          .where((f) => f.friendCode == _selectedFriendCode)
          .toList();
    }
    return _friends;
  }

  bool get _showMyPins => _mapFilterMode != MapFilterMode.singleFriend;

  /// 高精度GPS現在地を取得してマップを移動する
  Future<void> _fetchCurrentLocation({bool moveCamera = true}) async {
    setState(() {
      _isLoadingGps = true;
      _statusMessage = 'GPS測位中...';
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        throw Exception('端末の位置情報（GPS）が無効になっています。設定画面でONにしてください。');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('位置情報の利用権限が拒否されました。');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('位置情報の利用権限が永久に拒否されています。アプリの設定から許可してください。');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final newLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = newLatLng;
        _currentPosition = position;
        _isLoadingGps = false;
        _statusMessage =
            '現在地を取得しました（精度: ±${position.accuracy.toStringAsFixed(1)}m）';
      });

      if (moveCamera) {
        _mapController.move(newLatLng, 16.5);
      }
    } catch (e) {
      setState(() {
        _isLoadingGps = false;
        _statusMessage = 'エラー: ${e.toString().replaceAll("Exception: ", "")}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '設定を開く',
              textColor: Colors.yellowAccent,
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
    }
  }

  /// リアルタイムGPSストリームの切り替え
  Future<void> _toggleLiveTracking() async {
    if (_isLiveTracking) {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      setState(() {
        _isLiveTracking = false;
        _statusMessage = 'リアルタイム監視を停止しました';
      });
    } else {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _fetchCurrentLocation(moveCamera: false);
        if (_currentLatLng == null) return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final newLatLng = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLatLng = newLatLng;
            _currentPosition = position;
            _statusMessage =
                'リアルタイム測位中（精度: ±${position.accuracy.toStringAsFixed(1)}m）';
          });
        },
        onError: (Object e) {
          setState(() {
            _statusMessage = 'ストリームエラー: $e';
            _isLiveTracking = false;
          });
        },
      );

      setState(() {
        _isLiveTracking = true;
        _statusMessage = 'リアルタイム測位を開始しました';
      });
    }
  }

  /// ステップ④＆⑤：「＋ 店を登録（カメラ）」ボタンを押したときの処理
  Future<void> _openQuickRegisterSheet() async {
    if (_isSearchingShops) return;
    setState(() => _isSearchingShops = true);

    final targetLatLng = _activeBaseLatLng;
    List<NearbyCandidate> candidates = [];

    try {
      candidates = await _searchService.searchNearbyRestaurants(
        latitude: targetLatLng.latitude,
        longitude: targetLatLng.longitude,
        radiusMeters: 150,
      );
    } finally {
      if (mounted) {
        setState(() => _isSearchingShops = false);
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return QuickRegisterSheet(
          candidates: candidates,
          existingRecords: _records,
          currentLatLng: targetLatLng,
          onSubmit: _handleSaveOrChargeRestaurant,
          onAddToWantList: (candidate) {
            return _addWant(
              name: candidate.name,
              category: candidate.category,
              latitude: candidate.latitude,
              longitude: candidate.longitude,
              source: WantSource.search,
              showFeedback: false,
            );
          },
        );
      },
    );
  }

  /// ステップ⑥＆⑧：「マイ・グルメ名刺 ＆ 称号コレクション図鑑」画面を開く
  void _openGourmetCardSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GourmetCardSheet(
          initialUserName: _userName,
          customTitle: _customTitle,
          cardThemeIndex: _cardThemeIndex,
          isProMember: _isProMember,
          records: _records,
          friends: _friends,
          onUserNameChanged: (newName) {
            setState(() => _userName = newName);
            _storageService.saveUserName(newName);
            _friendService.scheduleSync(userName: newName, records: _records);
          },
          onCustomTitleChanged: (newTitle) {
            setState(() => _customTitle = newTitle);
            _storageService.saveCustomTitle(newTitle);
            _friendService.scheduleSync(userName: _userName, records: _records);
          },
          onCardThemeChanged: (newIndex) {
            setState(() => _cardThemeIndex = newIndex);
            _storageService.saveCardThemeIndex(newIndex);
          },
          onOpenPaywall: _openPremiumPaywallSheet,
        );
      },
    );
  }

  /// UI/UX改善：登録店舗一覧＆ランク別絞り込みシートを開く
  void _openShopListSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ShopListSheet(
          records: _records,
          onSelectShop: (record) {
            setState(() {
              if (_mapFilterMode == MapFilterMode.singleFriend) {
                _mapFilterMode = MapFilterMode.allWithFriends;
              }
            });
            _mapController.move(record.latLng, 17.2);
            _showRestaurantDetail(record);
          },
          onQuickCharge: (record) {
            _handleSaveOrChargeRestaurant(
              id: record.id,
              name: record.name,
              category: record.category,
              latitude: record.latitude,
              longitude: record.longitude,
              priceRange: record.priceRange,
              goodPoints: record.goodPoints,
              imagePath: record.imagePath,
              imageBase64: record.imageBase64,
            );
          },
        );
      },
    );
  }

  /// ステップ⑨：PRO課金導線＆広告非表示モーダルを開く
  void _openPremiumPaywallSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PremiumPaywallSheet(
          isProMember: _isProMember,
          onTogglePro: (nextPro) {
            setState(() {
              _isProMember = nextPro;
              if (!nextPro && _cardThemeIndex == 2) {
                _cardThemeIndex = 0;
              }
            });
            _storageService.saveIsProMember(nextPro);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nextPro
                      ? '👑 グルメマップ PRO を有効化しました！（広告非表示＆全テーマ解放）'
                      : '通常プラン表示に切り替えました',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor:
                    nextPro ? const Color(0xFF2E7D32) : Colors.blueGrey,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  /// ステップ⑦：「フレンド機能 ＆ マップ共有」画面を開く
  void _openFriendManagementSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return FriendManagementSheet(
              myFriendCode: _myFriendCode,
              userName: _userName,
              syncStatusText: _syncStatusText,
              friends: _friends,
              onSyncMyMap: () async {
                final res = await _friendService.syncMyMap(
                  userName: _userName,
                  records: _records,
                );
                setState(() => _pullSyncState());
                setSheetState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.message),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onReissueCode: () async {
                final res = await _friendService.reissueMyCode(
                  userName: _userName,
                  records: _records,
                );
                if (res.newCode != null) {
                  setState(() {
                    _myFriendCode = res.newCode!;
                    _pullSyncState();
                  });
                  setSheetState(() {});
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.message),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return res.newCode != null;
              },
              onRefreshFriends: () async {
                final updated = await _friendService.refreshFriends();
                setState(() => _friends = updated);
                setSheetState(() {});
              },
              onAddSampleFriend: (code) async {
                final res = await _friendService.addSampleFriend(
                  sampleCode: code,
                  baseLatLng: _activeBaseLatLng,
                );
                setState(() {
                  _friends = res.allFriends;
                  _mapFilterMode = MapFilterMode.allWithFriends;
                  _selectedFriendCode = null;
                });
                setSheetState(() {});
                if (res.friend.records.isNotEmpty) {
                  _mapController.move(res.friend.records.first.latLng, 16.3);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🧪 サンプル「${res.friend.avatarEmoji}${res.friend.displayName}」のマップを表示しました（体験用です）',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: res.friend.themeColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return true;
              },
              onAddFriendByCode: (code) async {
                final res = await _friendService.addFriendByCode(code);

                switch (res.status) {
                  case FriendFetchStatus.found:
                    final friend = res.friend!;
                    setState(() {
                      _friends = res.allFriends;
                      _mapFilterMode = MapFilterMode.allWithFriends;
                      _selectedFriendCode = null;
                    });
                    setSheetState(() {});
                    if (friend.records.isNotEmpty) {
                      _mapController.move(friend.records.first.latLng, 16.3);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '👥 フレンド「${friend.avatarEmoji}${friend.displayName}」のマップ（${friend.records.length}店舗）を共有表示しました！',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: friend.themeColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return true;
                  case FriendFetchStatus.notFound:
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('そのコードのフレンドは見つかりませんでした。コードを確認してください。'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return false;
                  case FriendFetchStatus.invalidFormat:
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'フレンドコードの形式が違います（例: GM-ABCDE-23456）。自分のコードは追加できません。'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return false;
                  case FriendFetchStatus.offline:
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('通信できなかったため確認できませんでした。電波の良い場所で再試行してください。'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return false;
                }
              },
              onRemoveFriend: (code) async {
                final updated = await _friendService.removeFriend(code);
                setState(() {
                  _friends = updated;
                  if (_selectedFriendCode == code) {
                    _selectedFriendCode = null;
                    _mapFilterMode = MapFilterMode.allWithFriends;
                  }
                });
                setSheetState(() {});
              },
              onSelectFriendMap: (friend) {
                setState(() {
                  _mapFilterMode = MapFilterMode.singleFriend;
                  _selectedFriendCode = friend.friendCode;
                });
                if (friend.records.isNotEmpty) {
                  _mapController.move(friend.records.first.latLng, 16.5);
                }
              },
              onShowAllFriendsMap: () {
                setState(() {
                  _mapFilterMode = MapFilterMode.allWithFriends;
                  _selectedFriendCode = null;
                });
              },
            );
          },
        );
      },
    );
  }

  /// 店舗の保存またはリピートチャージ（count + 1）を実行し、マップとゲーム演出を更新
  Future<void> _handleSaveOrChargeRestaurant({
    required String id,
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required String priceRange,
    required List<String> goodPoints,
    String? imagePath,
    String? imageBase64,
  }) async {
    final prevExp = GamificationEngine.calculateTotalExp(
      records: _records,
      friends: _friends,
    );

    final result = await _storageService.saveOrChargeRestaurant(
      id: id,
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      priceRange: priceRange,
      goodPoints: goodPoints,
      imagePath: imagePath,
      imageBase64: imageBase64,
    );

    if (!mounted) return;

    // 触覚フィードバック（スマホ実機で気持ちいい振動）
    unawaited(HapticFeedback.mediumImpact());

    setState(() {
      _records = result.allRecords;
      if (_mapFilterMode == MapFilterMode.singleFriend) {
        _mapFilterMode = MapFilterMode.allWithFriends;
      }
    });

    final newExp = GamificationEngine.calculateTotalExp(
      records: _records,
      friends: _friends,
    );
    final gainedExp = (newExp - prevExp).clamp(100, 1000);
    final levelInfo = GamificationEngine.calculateLevelInfo(
      records: _records,
      friends: _friends,
    );

    // フレンド機能 v2：記録の変更は自動でクラウド同期（デバウンス付き）
    _friendService.scheduleSync(userName: _userName, records: _records);

    // 登録・チャージした店舗の座標へカメラを移動
    _mapController.move(result.record.latLng, 17.0);

    // ステップ⑧：チャージ＆ランクアップ演出ダイアログを表示
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return ChargeCelebrationDialog(
            record: result.record,
            isRepeat: result.isRepeat,
            gainedExp: gainedExp,
            currentLevel: levelInfo.level,
          );
        },
      );
    }

    // N1：行きたいリストに同じ店があれば卒業させる
    if (!result.isRepeat && mounted) {
      final grad = await _storageService.graduateWantsFor(result.record);
      if (grad.graduatedCount > 0 && mounted) {
        setState(() => _wantList = grad.wants);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎓 「行きたいリスト」から卒業しました！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// マップ上の自分の店舗ピンをタップした際に詳細・シェアシートを表示
  void _showRestaurantDetail(RestaurantRecord record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return RestaurantDetailSheet(
          record: record,
          onQuickCharge: () {
            _handleSaveOrChargeRestaurant(
              id: record.id,
              name: record.name,
              category: record.category,
              latitude: record.latitude,
              longitude: record.longitude,
              priceRange: record.priceRange,
              goodPoints: record.goodPoints,
              imagePath: record.imagePath,
              imageBase64: record.imageBase64,
            );
          },
          onDelete: () async {
            Navigator.of(ctx).pop();
            final updated = await _storageService.deleteRecord(record.id);
            if (mounted) {
              setState(() => _records = updated);
              _friendService.scheduleSync(
                userName: _userName,
                records: updated,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「${record.name}」の記録を削除しました'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  /// F1/F2：自分とフレンドの店舗ピンを構築する。
  /// 近い場所のピンは合体ピンにまとめ、ズームアウト時はクラスタ化する。
  List<Marker> _buildShopMarkers(List<FriendProfile> visibleFriends) {
    final entries = <PinEntry>[
      if (_showMyPins)
        for (final record in _records) PinEntry(record: record),
      for (final friend in visibleFriends)
        for (final record in friend.records)
          PinEntry(record: record, friend: friend),
    ];
    final groups = groupPins(entries);

    if (clusteringEnabled(_currentZoom)) {
      final cells = clusterGroups(
        groups,
        clusterCellDegreesForZoom(_currentZoom),
      );
      return [
        for (final cell in cells)
          if (cell.length == 1)
            _markerForGroup(cell.first)
          else
            Marker(
              point: clusterCenter(cell),
              width: 62,
              height: 62,
              alignment: Alignment.center,
              child: ClusterPinMarker(
                shopCount:
                    cell.fold<int>(0, (sum, g) => sum + g.entries.length),
                onTap: () {
                  _mapController.move(
                    clusterCenter(cell),
                    (_currentZoom + 2).clamp(3.0, 17.5),
                  );
                },
              ),
            ),
      ];
    }

    return [for (final group in groups) _markerForGroup(group)];
  }

  /// グループ1件分のマーカー（単体なら通常ピン、複数なら合体ピン）。
  Marker _markerForGroup(PinGroup group) {
    if (!group.isMerged) {
      final entry = group.entries.first;
      if (entry.isMine) {
        final record = entry.record;
        return Marker(
          point: record.latLng,
          width: RestaurantPinMarker.markerWidthForCount(record.chargeCount),
          height: RestaurantPinMarker.markerHeightForCount(record.chargeCount),
          alignment: Alignment.center,
          child: RestaurantPinMarker(
            record: record,
            onTap: () => _showRestaurantDetail(record),
          ),
        );
      }
      final friend = entry.friend!;
      final record = entry.record;
      return Marker(
        point: record.latLng,
        width: 112,
        height: 102,
        alignment: Alignment.center,
        child: FriendPinMarker(
          friend: friend,
          record: record,
          onTap: () => _showFriendRestaurantDetail(friend, record),
        ),
      );
    }

    return Marker(
      point: group.point,
      width: 120,
      height: 92,
      alignment: Alignment.center,
      child: MergedPinMarker(
        group: group,
        onTap: () => _showPinGroupChooser(group),
      ),
    );
  }

  /// F1：合体ピンをタップしたときの選択シート（自分の記録／フレンドの記録）。
  void _showPinGroupChooser(PinGroup group) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              const Text(
                'この場所のお店',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                '見たい記録を選んでください',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              for (final entry in group.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: entry.isMine
                        ? const Color(0xFFFF5722)
                        : entry.friend!.themeColor,
                    child: Text(
                      entry.isMine ? '自' : entry.friend!.avatarEmoji,
                      style: TextStyle(
                        color: entry.isMine ? Colors.white : null,
                        fontSize: entry.isMine ? 13 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.record.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    entry.isMine
                        ? '自分の記録 • チャージ${entry.record.chargeCount}回'
                        : '${entry.friend!.displayName}さんの記録 • チャージ${entry.record.chargeCount}回',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (entry.isMine) {
                      _showRestaurantDetail(entry.record);
                    } else {
                      _showFriendRestaurantDetail(
                        entry.friend!,
                        entry.record,
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// マップ上の「フレンドの店舗ピン」をタップした際の詳細シートを表示
  void _showFriendRestaurantDetail(
    FriendProfile friend,
    RestaurantRecord record,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FriendRestaurantDetailSheet(
          friend: friend,
          record: record,
          onAddToWantList: friend.isSample
              ? null
              : () {
                  _addWant(
                    name: record.name,
                    category: record.category,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    source: WantSource.friend,
                    sourceLabel: friend.displayName,
                  );
                },
          onImportToMyMap: () {
            _handleSaveOrChargeRestaurant(
              id: record.id,
              name: record.name,
              category: record.category,
              latitude: record.latitude,
              longitude: record.longitude,
              priceRange: record.priceRange,
              goodPoints: record.goodPoints,
            );
          },
        );
      },
    );
  }

  /// Yahoo!ローカルサーチAPI (YOLP) / モック切り替え設定ダイアログ
  void _showApiSettingsDialog() {
    final controller =
        TextEditingController(text: RestaurantSearchService.yahooAppId);
    bool localForceMock = RestaurantSearchService.forceMockMode;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                '周辺検索API設定 (Yahoo! YOLP)',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'テスト用モック3店舗を強制使用',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      localForceMock
                          ? '現在：モック3件（ラーメン・カフェ・カレー）'
                          : '現在：Yahoo!ローカルサーチAPI 実データ通信',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    value: localForceMock,
                    onChanged: (val) {
                      setDialogState(() => localForceMock = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Yahoo! Client ID (AppID)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      RestaurantSearchService.yahooAppId =
                          controller.text.trim();
                      RestaurantSearchService.forceMockMode = localForceMock;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          RestaurantSearchService.isMockMode
                              ? 'モック検索モードに設定しました'
                              : 'Yahoo!ローカルサーチAPI（実データ）に設定しました',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleFriends = _visibleFriends;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 地図表示（flutter_map + OpenStreetMap）
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _tokyoStation,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              onPositionChanged: (camera, hasGesture) {
                if ((camera.zoom - _currentZoom).abs() > 0.05) {
                  setState(() => _currentZoom = camera.zoom);
                }
              },
              onLongPress: (tapPosition, point) {
                _handleMapLongPress(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gourmet_map',
                maxZoom: 19,
              ),

              // 現在地マーカーレイヤー（青いパルスマーカー）
              MarkerLayer(
                markers: [
                  if (_currentLatLng != null)
                    Marker(
                      point: _currentLatLng!,
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44 * _pulseAnimation.value,
                                height: 44 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withValues(
                                    alpha: 0.25 / _pulseAnimation.value,
                                  ),
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1976D2),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),

              // F1/F2：自分＋フレンドの店舗ピンを統合レイヤーで表示
              // （同一地点は合体ピン、ズームアウト時はクラスタピンに集約）
              MarkerLayer(markers: _buildShopMarkers(visibleFriends)),

              // N1：行きたい店ピン（フレンド単独表示モードでは隠す）
              if (_mapFilterMode != MapFilterMode.singleFriend)
                MarkerLayer(
                  markers: [
                    for (final want in _wantList)
                      Marker(
                        point: want.latLng,
                        width: 110,
                        height: 62,
                        alignment: Alignment.center,
                        child: WantPinMarker(
                          want: want,
                          onTap: () => _showWantDetail(want),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          // 2. 画面上部：洗練されたプレイヤーレベル・称号ヘッダー ＋ マップ切替ピルバー
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernHeaderCard(),
                  const SizedBox(height: 8),
                  _buildFriendMapSwitchBar(),
                ],
              ),
            ),
          ),

          // 3. 画面右下：シンプルな地図操作ボタン（現在地取得・東京駅リセット）
          Positioned(
            right: 14,
            bottom: _isProMember ? 104 : 152,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'reset_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey.shade800,
                  tooltip: '東京駅へ戻る',
                  onPressed: () {
                    _mapController.move(_tokyoStation, 16.0);
                  },
                  child: const Icon(Icons.home_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'gps_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1976D2),
                  elevation: 4,
                  tooltip: '現在地へ移動',
                  onPressed: _isLoadingGps
                      ? null
                      : () => _fetchCurrentLocation(moveCamera: true),
                  child: _isLoadingGps
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // 4. 画面下部：AdMobスマートバナー（ステップ⑨） ＋ 統合ボトムアクションドック（UI/UX改善）
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isProMember) ...[
                    AdMobSmartBanner(
                      isProMember: _isProMember,
                      onTapRemoveAds: _openPremiumPaywallSheet,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildUnifiedBottomDock(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// UI/UX改善：画面上部のモダンなプレイヤーLv・称号・統計カード（GPS詳細は折りたたみ開閉式）
  Widget _buildModernHeaderCard() {
    final levelInfo = GamificationEngine.calculateLevelInfo(
      records: _records,
      friends: _friends,
    );
    final badges = GamificationEngine.evaluateBadges(
      records: _records,
      friends: _friends,
    );
    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final totalCharges =
        _records.fold<int>(0, (sum, item) => sum + item.chargeCount);

    final latText = _currentPosition != null
        ? _currentPosition!.latitude.toStringAsFixed(5)
        : (_currentLatLng != null
            ? _currentLatLng!.latitude.toStringAsFixed(5)
            : '35.68124');

    final lngText = _currentPosition != null
        ? _currentPosition!.longitude.toStringAsFixed(5)
        : (_currentLatLng != null
            ? _currentLatLng!.longitude.toStringAsFixed(5)
            : '139.76713');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color:
              _isProMember ? const Color(0xFFFFD700) : Colors.orange.shade100,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // レベルサークル（タップでグルメ名刺・称号図鑑へ）
              GestureDetector(
                onTap: _openGourmetCardSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5722), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LEVEL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${levelInfo.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // プレイヤー名・装備称号・EXPバー
              Expanded(
                child: GestureDetector(
                  onTap: _openGourmetCardSheet,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: levelInfo.progress,
                                minHeight: 5,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF5722),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '🏆$unlockedCount/${badges.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 店舗数・チャージ数ピル（タップで登録店リストへ）
              InkWell(
                onTap: _openShopListSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_records.length}店',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD84315),
                        ),
                      ),
                      Text(
                        '⚡$totalCharges回',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // GPS詳細・API設定の開閉トグルボタン
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: 'GPS座標・API設定を表示',
                onPressed: () {
                  setState(() {
                    _showGpsDebugDetails = !_showGpsDebugDetails;
                  });
                },
                icon: Icon(
                  _showGpsDebugDetails
                      ? Icons.expand_less
                      : Icons.radar_rounded,
                  size: 20,
                  color: _currentPosition != null
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),

          // 折りたたみ式：GPSリアルタイム座標＆Yahoo! API設定パネル（ステップ③・④確認用）
          if (_showGpsDebugDetails) ...[
            const Divider(height: 12, thickness: 0.8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentPosition != null
                        ? Colors.green.shade600
                        : Colors.blueGrey,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _currentPosition != null ? 'GPS ON' : 'GPS待機',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lat: $latText / Lng: $lngText • $_statusMessage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _toggleLiveTracking,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isLiveTracking
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isLiveTracking
                            ? Colors.green
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      _isLiveTracking ? '● LIVE' : 'LIVE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _isLiveTracking
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _showApiSettingsDialog,
                  child:
                      const Icon(Icons.tune, size: 17, color: Colors.black54),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: '$latText, $lngText'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('座標をコピーしました'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child:
                      const Icon(Icons.copy, size: 16, color: Colors.black54),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// UI/UX改善：片手親指で快適に操作できる統合ボトムアクションドック
  Widget _buildUnifiedBottomDock() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.orange.shade100, width: 1.5),
        ),
        child: Row(
          children: [
            // 左：グルメ名刺・称号ボタン
            Expanded(
              flex: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openGourmetCardSheet,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF212121),
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '名刺・称号',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 中央：特大メイン「＋ 店を登録（カメラ）」ボタン
            Expanded(
              flex: 6,
              child: SizedBox(
                height: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFFF5722).withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: _isSearchingShops ? null : _openQuickRegisterSheet,
                  icon: _isSearchingShops
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_a_photo, size: 20),
                  label: Text(
                    _isSearchingShops ? '検索中...' : '＋ 店を登録',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

            // 右：フレンド共有ボタン
            Expanded(
              flex: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openFriendManagementSheet,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      color: Color(0xFF7B1FA2),
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _friends.isEmpty ? 'フレンド' : 'フレンド(${_friends.length})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// マップ表示フィルター＆店舗図鑑ショートカットピルバー
  Widget _buildFriendMapSwitchBar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterPill(
            label: '👥 自分＋友達 (${_friends.length})',
            isSelected: _mapFilterMode == MapFilterMode.allWithFriends,
            activeColor: const Color(0xFF7B1FA2),
            onTap: () {
              setState(() {
                _mapFilterMode = MapFilterMode.allWithFriends;
                _selectedFriendCode = null;
              });
            },
          ),
          const SizedBox(width: 6),
          _buildFilterPill(
            label: '📍 自分のみ (${_records.length})',
            isSelected: _mapFilterMode == MapFilterMode.mineOnly,
            activeColor: const Color(0xFFFF5722),
            onTap: () {
              setState(() {
                _mapFilterMode = MapFilterMode.mineOnly;
                _selectedFriendCode = null;
              });
            },
          ),
          const SizedBox(width: 6),
          ..._friends.map((friend) {
            final isSelected = _mapFilterMode == MapFilterMode.singleFriend &&
                _selectedFriendCode == friend.friendCode;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterPill(
                label:
                    '${friend.avatarEmoji} ${friend.displayName} (${friend.records.length})',
                isSelected: isSelected,
                activeColor: friend.themeColor,
                onTap: () {
                  setState(() {
                    _mapFilterMode = MapFilterMode.singleFriend;
                    _selectedFriendCode = friend.friendCode;
                  });
                  if (friend.records.isNotEmpty) {
                    _mapController.move(friend.records.first.latLng, 16.5);
                  }
                },
              ),
            );
          }),
          _buildFilterPill(
            label: '📋 登録店リスト',
            isSelected: false,
            activeColor: Colors.brown.shade700,
            onTap: _openShopListSheet,
          ),
          const SizedBox(width: 6),
          _buildFilterPill(
            label: '🔖 行きたい (${_wantList.length})',
            isSelected: false,
            activeColor: const Color(0xFF00897B),
            onTap: _openWantListSheet,
          ),
          const SizedBox(width: 6),
          _buildFilterPill(
            label: _isProMember ? '👑 PRO有効中' : '👑 PRO特典',
            isSelected: _isProMember,
            activeColor: const Color(0xFFE65100),
            onTap: _openPremiumPaywallSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
