import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:web/web.dart' as web;
import '../../auth/data/auth_service.dart';
import '../../pricing/data/tier_service.dart';

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._();
  static FirebaseService get instance => _instance;

  FirebaseService._();

  String? _sessionId;
  bool _isConnected = false;
  bool _wasEverConnected = false;
  bool _isViewOnly = false;

  final List<Map<String, dynamic>> logs = [];
  final List<Map<String, dynamic>> networkRequests = [];
  final List<Map<String, dynamic>> performanceData = [];
  final List<Map<String, dynamic>> crashes = [];
  final List<Map<String, dynamic>> navigationEvents = [];
  final List<Map<String, dynamic>> reports = [];
  Map<String, dynamic>? deviceInfo;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _stalenessTimer;
  Timer? _debounceTimer;
  int _lastSeenMs = 0;

  // ── Incremental Network Stats ────────────────────────────────────
  int _networkTotalTime = 0;
  int _networkWithTimeCount = 0;
  int _networkSuccessCount = 0;
  int _networkErrorCount = 0;

  Map<String, dynamic> get networkStats {
    final total = networkRequests.length;
    return {
      'total': total,
      'success': _networkSuccessCount,
      'errors': _networkErrorCount,
      'avgTime': _networkWithTimeCount > 0
          ? (_networkTotalTime / _networkWithTimeCount).round()
          : 0,
      'successRate': total > 0 ? (_networkSuccessCount / total * 100) : 0.0,
    };
  }

  void _debouncedNotify() {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      notifyListeners();
    });
  }

  static const int _maxPerformance = 120;
  static const int _maxCrashes = 100;
  static const int _maxNavigation = 200;

  bool get isConnected => _isConnected;
  bool get isViewOnly => _isViewOnly;
  String? get sessionId => _sessionId;

  // ── Tier-aware capacity tracking ─────────────────────────────────
  bool _logsAtCapacity = false;
  bool _networkAtCapacity = false;

  final List<DatabaseReference> _logRefs = [];
  final List<DatabaseReference> _networkRefs = [];

  bool get logsAtCapacity => _logsAtCapacity;
  bool get networkAtCapacity => _networkAtCapacity;

  TierConfig get _tierConfig =>
      TierService.instance.configFor(AuthService.instance.tier);

  void startListening(String sessionId, {bool viewOnly = false}) {
    _clearSubscriptions();
    _sessionId = sessionId;
    _isViewOnly = viewOnly;

    try {
      if (!viewOnly) {
        web.window.localStorage.setItem('active_session_id', sessionId);
      }
    } catch (_) {}

    try {
      final db = FirebaseDatabase.instance.ref('sessions/$sessionId');

      // Mark session as disconnected if web app closes/refreshes (only for non-view-only)
      if (!viewOnly) {
        db.child('status').onDisconnect().update({'connected': false});
      }

      // Listen for connection status
      _subscriptions.add(
        db.child('status').onValue.listen((event) {
          final data = event.snapshot.value as Map?;
          if (data != null && data['connected'] == true) {
            _isConnected = true;
            _wasEverConnected = true;

            // Track lastSeen for staleness detection
            if (data['lastSeen'] is int) {
              _lastSeenMs = data['lastSeen'] as int;
            }

            _debouncedNotify();
          } else {
            final wasConnected = _isConnected || _wasEverConnected;
            _isConnected = false;
            _debouncedNotify();

            // Only save session + clear localStorage if a real connection existed
            if (wasConnected) {
              saveSessionSummary(uptime: const Duration(seconds: 0));
              try {
                web.window.localStorage.removeItem('active_session_id');
              } catch (_) {}
            }
          }
        }),
      );

      // Periodic staleness check — if the device hasn't written a heartbeat
      // in 10+ seconds, it likely crashed/restarted without calling stop().
      _stalenessTimer?.cancel();
      _stalenessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isConnected && _lastSeenMs > 0) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastSeenMs > 10000) {
            debugPrint('Device heartbeat stale — marking as disconnected.');
            _isConnected = false;
            _debouncedNotify();
          }
        }
      });

      // Listen for logs
      _subscriptions.add(
        db.child('logs').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            final config = _tierConfig;

            logs.insert(0, Map<String, dynamic>.from(data));
            _logRefs.insert(0, event.snapshot.ref);

            if (logs.length > config.maxLogsPerSession) {
              _logsAtCapacity = true;
              logs.removeLast();
              final oldRef = _logRefs.removeLast();
              if (!_isViewOnly) {
                oldRef.remove();
              }
            } else {
              _logsAtCapacity = logs.length == config.maxLogsPerSession;
            }
            _debouncedNotify();
          }
        }),
      );

      // Listen for network requests
      _subscriptions.add(
        db.child('network').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            final config = _tierConfig;

            final reqData = Map<String, dynamic>.from(data);
            networkRequests.insert(0, reqData);
            _networkRefs.insert(0, event.snapshot.ref);

            // Increment stats
            final res = reqData['response'];
            if (res is Map) {
              final code = res['statusCode'];
              if (code is int) {
                if (code < 400) {
                  _networkSuccessCount++;
                } else {
                  _networkErrorCount++;
                }
              }
              final dur = res['durationMs'];
              if (dur is int) {
                _networkTotalTime += dur;
                _networkWithTimeCount++;
              }
            }

            if (networkRequests.length > config.maxNetworkPerSession) {
              _networkAtCapacity = true;
              final oldReq = networkRequests.removeLast();
              final oldRef = _networkRefs.removeLast();

              // Decrement stats
              final oldRes = oldReq['response'];
              if (oldRes is Map) {
                final code = oldRes['statusCode'];
                if (code is int) {
                  if (code < 400) {
                    _networkSuccessCount--;
                  } else {
                    _networkErrorCount--;
                  }
                }
                final dur = oldRes['durationMs'];
                if (dur is int) {
                  _networkTotalTime -= dur;
                  _networkWithTimeCount--;
                }
              }

              if (!_isViewOnly) {
                oldRef.remove();
              }
            } else {
              _networkAtCapacity =
                  networkRequests.length == config.maxNetworkPerSession;
            }
            _debouncedNotify();
          }
        }),
      );

      // Listen for performance metrics
      _subscriptions.add(
        db.child('performance').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            performanceData.add(Map<String, dynamic>.from(data));
            if (performanceData.length > _maxPerformance) {
              performanceData.removeAt(0);
            }
            _debouncedNotify();
          }
        }),
      );

      // Listen for crashes
      _subscriptions.add(
        db.child('crashes').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            crashes.insert(0, Map<String, dynamic>.from(data));
            if (crashes.length > _maxCrashes) crashes.removeLast();
            _debouncedNotify();
          }
        }),
      );

      // Listen for navigation events
      _subscriptions.add(
        db.child('navigation').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            navigationEvents.insert(0, Map<String, dynamic>.from(data));
            if (navigationEvents.length > _maxNavigation) {
              navigationEvents.removeLast();
            }
            _debouncedNotify();
          }
        }),
      );

      // Listen for device info (single value, not a list)
      _subscriptions.add(
        db.child('deviceInfo').onValue.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            deviceInfo = Map<String, dynamic>.from(data);
            _debouncedNotify();
          }
        }),
      );

      // Listen for reports attached to this session
      _subscriptions.add(
        db.child('reports').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            final report = Map<String, dynamic>.from(data);
            final id = report['reportId'] ?? event.snapshot.key;
            report['reportId'] = id;
            if (!reports.any((r) => r['reportId'] == id)) {
              reports.insert(0, report);
              _debouncedNotify();
            }
          }
        }),
      );
      _subscriptions.add(
        db.child('reports').onChildChanged.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            final report = Map<String, dynamic>.from(data);
            final id = report['reportId'] ?? event.snapshot.key;
            report['reportId'] = id;
            final idx = reports.indexWhere((r) => r['reportId'] == id);
            if (idx != -1) {
              reports[idx] = report;
            } else {
              reports.insert(0, report);
            }
            _debouncedNotify();
          }
        }),
      );
    } catch (e) {
      debugPrint('Firebase Database Error: $e');
    }
  }

  void _clearSubscriptions() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    reports.clear();
    _stalenessTimer?.cancel();
    _stalenessTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isConnected = false;
    _wasEverConnected = false;
    _lastSeenMs = 0;
  }

  // ── Session Management ──────────────────────────────────────────────

  /// Save a session summary to Firebase for session history.
  Future<void> saveSessionSummary({required Duration uptime}) async {
    if (_sessionId == null) return;
    try {
      final summary = {
        'sessionId': _sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'durationSeconds': uptime.inSeconds,
        'requestCount': networkRequests.length,
        'errorCount': crashes.length,
        'logCount': logs.length,
        'device': deviceInfo?['deviceModel'] ?? 'Unknown',
        'platform': deviceInfo?['platform'] ?? 'Unknown',
      };
      await FirebaseDatabase.instance
          .ref('session_history/$_sessionId')
          .set(summary);
    } catch (e) {
      debugPrint('Failed to save session summary: $e');
    }
  }

  /// Load past session summaries.
  Future<List<Map<String, dynamic>>> loadSessionHistory() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('session_history')
          .orderByChild('timestamp')
          .limitToLast(20)
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final sessions = data.values
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        sessions.sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );
        return sessions;
      }
    } catch (e) {
      debugPrint('Failed to load session history: $e');
    }
    return [];
  }

  // ── Bug Report ──────────────────────────────────────────────────────

  /// Generate a bug report and save it to Firebase. Returns the report ID.
  Future<String?> generateBugReport({String? title, String? notes}) async {
    if (_sessionId == null) return null;
    try {
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();
      final report = {
        'reportId': reportId,
        'sessionId': _sessionId,
        'title': title ?? 'Bug Report',
        'notes': notes ?? '',
        'createdAt': DateTime.now().toIso8601String(),
        'deviceInfo': deviceInfo,
        'recentNetworkRequests': networkRequests.take(10).toList(),
        'recentLogs': logs.take(20).toList(),
        'crashes': crashes.take(10).toList(),
        'navigationHistory': navigationEvents.take(20).toList(),
      };
      await FirebaseDatabase.instance.ref('reports/$reportId').set(report);
      try {
        await FirebaseDatabase.instance
            .ref('sessions/$_sessionId/reports/$reportId')
            .set(report);
      } catch (_) {}
      return reportId;
    } catch (e) {
      debugPrint('Failed to generate bug report: $e');
      return null;
    }
  }

  /// Load a bug report by ID.
  Future<Map<String, dynamic>?> loadBugReport(String reportId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('reports/$reportId')
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      if (_sessionId != null) {
        final sessionSnap = await FirebaseDatabase.instance
            .ref('sessions/$_sessionId/reports/$reportId')
            .get();
        if (sessionSnap.exists && sessionSnap.value is Map) {
          return Map<String, dynamic>.from(sessionSnap.value as Map);
        }
      }
    } catch (e) {
      debugPrint('Failed to load bug report: $e');
    }
    return null;
  }

  /// Load recent bug reports list.
  Future<List<Map<String, dynamic>>> loadPastReports() async {
    final Map<String, Map<String, dynamic>> byId = {};
    try {
      // 1. Fetch from global reports
      final snapshot = await FirebaseDatabase.instance
          .ref('reports')
          .orderByChild('createdAt')
          .limitToLast(50)
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final m = Map<String, dynamic>.from(entry.value as Map);
            m['reportId'] = m['reportId'] ?? entry.key;
            byId[m['reportId'].toString()] = m;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load global reports: $e');
    }

    try {
      // 2. Fetch from active session if present
      if (_sessionId != null) {
        final sessionSnap = await FirebaseDatabase.instance
            .ref('sessions/$_sessionId/reports')
            .get();
        if (sessionSnap.exists && sessionSnap.value is Map) {
          final data = Map<String, dynamic>.from(sessionSnap.value as Map);
          for (final entry in data.entries) {
            if (entry.value is Map) {
              final m = Map<String, dynamic>.from(entry.value as Map);
              m['reportId'] = m['reportId'] ?? entry.key;
              byId[m['reportId'].toString()] = m;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load session reports: $e');
    }

    final result = byId.values.toList();
    result.sort((a, b) {
      final ta = (a['createdAt'] ?? a['timestamp'] ?? '').toString();
      final tb = (b['createdAt'] ?? b['timestamp'] ?? '').toString();
      return tb.compareTo(ta);
    });
    return result;
  }

  void disconnect() {
    if (_sessionId != null && !_isViewOnly) {
      try {
        FirebaseDatabase.instance.ref('sessions/$_sessionId/status').update({
          'connected': false,
        });
      } catch (_) {}
    }

    _clearSubscriptions();
    _isConnected = false;
    _sessionId = null;
    _logsAtCapacity = false;
    _networkAtCapacity = false;
    _networkTotalTime = 0;
    _networkWithTimeCount = 0;
    _networkSuccessCount = 0;
    _networkErrorCount = 0;
    _logRefs.clear();
    _networkRefs.clear();

    try {
      web.window.localStorage.removeItem('active_session_id');
    } catch (_) {}

    _isViewOnly = false;
    _wasEverConnected = false;
    logs.clear();
    networkRequests.clear();
    performanceData.clear();
    crashes.clear();
    navigationEvents.clear();
    deviceInfo = null;
    notifyListeners();
  }
}
