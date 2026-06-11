import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models/notification_item.dart';
import 'screens/access_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.loadPersistedState();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Smishing App',
      debugShowCheckedModeBanner: false,
      home: NotificationBridge(
        navigatorKey: _navigatorKey,
        child: const AccessScreen(),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
	      builder: (context, child) {
	        return MediaQuery(
	          data: MediaQuery.of(context).copyWith(
	            textScaler: TextScaler.linear(appState.fontSize),
	          ),
	          child: child!,
	        );
	      },
    );
  }
}

class NotificationBridge extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const NotificationBridge({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends State<NotificationBridge> {
  static const String _deviceId = 'android-test-device';

  static const List<String> _channelCandidates = <String>[
    'smishing/notifications',
    'notification_listener/events',
    'notification_listener',
    'app.notifications',
  ];

  final List<NotificationItem> _items = <NotificationItem>[];
  final Set<String> _alertedResultIds = <String>{};
  final Set<String> _alertedFallbackKeys = <String>{};

  StreamSubscription<dynamic>? _streamSub;
  String? _boundChannel;
  String? _streamError;
  bool _isAlertOpen = false;

  @override
  void initState() {
    super.initState();
    _bindEventChannel(0);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _bindEventChannel(int index) {
    if (index >= _channelCandidates.length) {
      if (!mounted) return;
      setState(() {
        _streamError =
            'EventChannel 연결 실패: Android 채널명을 확인하세요 (${_channelCandidates.join(', ')})';
      });
      return;
    }

    final String channelName = _channelCandidates[index];
    final EventChannel channel = EventChannel(channelName);

    _streamSub?.cancel();
    _streamSub = channel.receiveBroadcastStream().listen(
      (dynamic payload) async {
        if (!mounted) return;

        if (_boundChannel != channelName) {
          setState(() {
            _boundChannel = channelName;
            _streamError = null;
          });
        }

        await _handleIncomingNotification(payload);
      },
      onError: (Object error) {
        final bool missingPlugin =
            error is MissingPluginException ||
            error.toString().contains('MissingPluginException');

        if (missingPlugin) {
          _bindEventChannel(index + 1);
          return;
        }

        if (!mounted) return;
        setState(() {
          _streamError = 'Event stream error: $error';
        });
      },
      cancelOnError: false,
    );
  }

  Future<void> _handleIncomingNotification(dynamic payload) async {
    Map<String, dynamic>? map;

    if (payload is Map) {
      map = payload.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
    } else if (payload is String) {
      map = <String, dynamic>{
        'packageName': 'unknown.app',
        'title': 'Notification',
        'text': payload,
      };
    }

    if (map == null) return;

    final String packageName = _pickString(
      map,
      <String>['packageName', 'package_name', 'pkg', 'sourceApp', 'source_app'],
      fallback: 'unknown.app',
    );

    final String title = _pickString(
      map,
      <String>['title', 'notificationTitle', 'appName'],
      fallback: '알림',
    );

    final String text = _pickString(
      map,
      <String>['text', 'content', 'message', 'messageText', 'body'],
      fallback: '',
    );

    final List<String> urlsFromPayload = _toStringList(map['urls']);
    final List<String> urls =
        urlsFromPayload.isNotEmpty ? urlsFromPayload : _extractUrls(text);

    if (urls.isEmpty) return;

    final String firstUrl = urls.first;

    try {
      final Map<String, dynamic> response = await ApiService.scanUrl(
        deviceId: _deviceId,
        url: firstUrl,
        sourceApp: packageName,
      );

      final NotificationItem item = NotificationItem.fromScanResponse(
        packageName: packageName,
        title: title,
        text: text,
        urls: urls,
        response: response,
      );

      _appendItem(item);
      await _showRiskAlertIfNeeded(item);
    } catch (e) {
      final NotificationItem errorItem = NotificationItem.withError(
        packageName: packageName,
        title: title,
        text: text,
        urls: urls,
        errorMessage: e.toString(),
      );
      _appendItem(errorItem);
    }
  }

  void _appendItem(NotificationItem item) {
    if (!mounted) return;

    setState(() {
      _items.insert(0, item);
      if (_items.length > 100) {
        _items.removeRange(100, _items.length);
      }
    });
  }

  Future<void> _showRiskAlertIfNeeded(NotificationItem item) async {
    final String grade = (item.finalRiskGrade ?? '').toUpperCase();
    if (grade != 'DANGER' && grade != 'SUSPICIOUS') return;

    if (item.resultId != null && item.resultId!.isNotEmpty) {
      if (_alertedResultIds.contains(item.resultId)) return;
      _alertedResultIds.add(item.resultId!);
    } else {
      final String fallbackKey = _fallbackAlertKey(item);
      if (_alertedFallbackKeys.contains(fallbackKey)) return;
      _alertedFallbackKeys.add(fallbackKey);
    }

    if (_isAlertOpen) return;

    final BuildContext? context = widget.navigatorKey.currentContext;
    if (context == null) return;

    _isAlertOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RiskAlertDialog(
        item: item,
        levelColor: _gradeColor(grade),
        onViewDetail: () {
          Navigator.of(context).pop();
          _openDetailSheet(context, item);
        },
      ),
    );

    _isAlertOpen = false;
  }

  String _fallbackAlertKey(NotificationItem item) {
    final String firstUrl = item.urls.isNotEmpty ? item.urls.first : '-';
    return '${item.packageName}|${item.title}|$firstUrl|${item.finalRiskGrade ?? 'UNKNOWN'}';
  }

  void _openDetailSheet(BuildContext context, NotificationItem selected) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _NotificationListContent(
              items: _items,
              initialItem: selected,
            ),
          ),
        );
      },
    );
  }

  List<String> _extractUrls(String content) {
    if (content.trim().isEmpty) return const <String>[];

    final RegExp urlRegex = RegExp(
      r'''(?:https?://|www\.)[^\s<>"']+''',
      caseSensitive: false,
    );

    final Set<String> urls = <String>{};

    for (final RegExpMatch match in urlRegex.allMatches(content)) {
      String value = match.group(0) ?? '';
      value = value.trim().replaceAll(RegExp(r'[\.,;:!\?\)\]\}>]+$'), '');
      if (value.isEmpty) continue;
      if (value.toLowerCase().startsWith('www.')) {
        value = 'https://$value';
      }
      urls.add(value);
    }

    return urls.toList();
  }

  String _pickString(
    Map<String, dynamic> source,
    List<String> keys, {
    required String fallback,
  }) {
    for (final String key in keys) {
      final dynamic value = source[key];
      if (value == null) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'DANGER':
        return Colors.red;
      case 'SUSPICIOUS':
        return Colors.orange;
      case 'SAFE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        if (_boundChannel != null || _streamError != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(10),
              color: _streamError == null
                  ? Colors.black.withValues(alpha: 0.65)
                  : Colors.red.withValues(alpha: 0.9),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  _streamError ?? '알림 수신 채널: $_boundChannel',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        if (_items.isNotEmpty)
          Positioned(
            right: 14,
            bottom:
                (_boundChannel != null || _streamError != null) ? 56 : 14,
            child: FloatingActionButton.extended(
              heroTag: 'notif_result_fab',
              onPressed: () => _openDetailSheet(context, _items.first),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text('알림 ${_items.length}'),
            ),
          ),
      ],
    );
  }
}

class _RiskAlertDialog extends StatelessWidget {
  final NotificationItem item;
  final Color levelColor;
  final VoidCallback onViewDetail;

  const _RiskAlertDialog({
    required this.item,
    required this.levelColor,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final String grade = (item.finalRiskGrade ?? 'UNKNOWN').toUpperCase();
    final String firstUrl = item.urls.isNotEmpty ? item.urls.first : '-';

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: levelColor),
          const SizedBox(width: 8),
          Text('위험 경고: $grade'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _kv('앱명', item.packageName),
            _kv('제목', item.title.isEmpty ? '-' : item.title),
            _kv('본문', item.text.isEmpty ? '-' : item.text),
            _kv('URL', firstUrl),
            _kv('최종 등급', grade),
            _kv('위험 점수', item.finalRiskScore?.toString() ?? '-'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: onViewDetail,
          child: const Text('상세 보기'),
        ),
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.35),
          children: <InlineSpan>[
            TextSpan(
              text: '$key: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _NotificationListContent extends StatelessWidget {
  final List<NotificationItem> items;
  final NotificationItem initialItem;

  const _NotificationListContent({
    required this.items,
    required this.initialItem,
  });

  @override
  Widget build(BuildContext context) {
    final List<NotificationItem> ordered = <NotificationItem>[
      initialItem,
      ...items.where((NotificationItem e) => !identical(e, initialItem)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '알림 검사 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ordered.length,
            itemBuilder: (BuildContext context, int index) {
              return _NotificationResultCard(item: ordered[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationResultCard extends StatelessWidget {
  final NotificationItem item;

  const _NotificationResultCard({required this.item});

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'DANGER':
        return Colors.red;
      case 'SUSPICIOUS':
        return Colors.orange;
      case 'SAFE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _safeBrowsingText(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return '-';
    return list
        .map((Map<String, dynamic> e) {
          final String url = (e['url'] ?? '-').toString();
          final String malicious = (e['isMalicious'] ?? '-').toString();
          return '$url (isMalicious=$malicious)';
        })
        .join('\n');
  }

  String _d(double? value, {int n = 6}) =>
      value == null ? '-' : value.toStringAsFixed(n);
  String _b(bool? value) => value == null ? '-' : value.toString();

  @override
  Widget build(BuildContext context) {
    final String grade = (item.finalRiskGrade ?? 'UNKNOWN').toUpperCase();
    final Color color = _gradeColor(grade);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.title.isEmpty ? '(제목 없음)' : item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('앱: ${item.packageName}'),
            Text('본문: ${item.text.isEmpty ? '-' : item.text}'),
            Text('URL: ${item.urls.isEmpty ? '-' : item.urls.join(', ')}'),
            Text('최종 점수: ${item.finalRiskScore?.toString() ?? '-'}'),
            Text('Safe Browsing: ${_safeBrowsingText(item.safeBrowsing)}'),
            Text(
                'XGBoost used/score/verdict: ${_b(item.xgboostUsed)} / ${_d(item.xgboostScore)} / ${item.xgboostVerdict ?? '-'}'),
            Text(
                'KcELECTRA used/score/intent/verdict: ${_b(item.kcelectraUsed)} / ${_d(item.kcelectraScore)} / ${item.kcelectraIntent ?? '-'} / ${item.kcelectraVerdict ?? '-'}'),
            Text('분석 시각: ${item.analyzedAt ?? '-'}'),
            if (item.errorMessage != null && item.errorMessage!.isNotEmpty)
              Text(
                '에러: ${item.errorMessage}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}
