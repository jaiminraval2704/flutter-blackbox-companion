import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:web/web.dart' as web;

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
  Map<String, dynamic>? deviceInfo;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _stalenessTimer;
  int _lastSeenMs = 0;

  // ── List capacity limits to prevent memory leaks ──────────────────
  static const int _maxLogs = 500;
  static const int _maxNetwork = 500;
  static const int _maxPerformance = 120;
  static const int _maxCrashes = 100;
  static const int _maxNavigation = 200;

  bool get isConnected => _isConnected;
  bool get isViewOnly => _isViewOnly;
  String? get sessionId => _sessionId;

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

            notifyListeners();
          } else {
            final wasConnected = _isConnected || _wasEverConnected;
            _isConnected = false;
            notifyListeners();

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
            notifyListeners();
          }
        }
      });

      // Listen for logs
      _subscriptions.add(
        db.child('logs').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            logs.insert(0, Map<String, dynamic>.from(data));
            if (logs.length > _maxLogs) logs.removeLast();
            notifyListeners();
          }
        }),
      );

      // Listen for network requests
      _subscriptions.add(
        db.child('network').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            networkRequests.insert(0, Map<String, dynamic>.from(data));
            if (networkRequests.length > _maxNetwork)
              networkRequests.removeLast();
            notifyListeners();
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
            notifyListeners();
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
            notifyListeners();
          }
        }),
      );

      // Listen for navigation events
      _subscriptions.add(
        db.child('navigation').onChildAdded.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            navigationEvents.insert(0, Map<String, dynamic>.from(data));
            if (navigationEvents.length > _maxNavigation)
              navigationEvents.removeLast();
            notifyListeners();
          }
        }),
      );

      // Listen for device info (single value, not a list)
      _subscriptions.add(
        db.child('deviceInfo').onValue.listen((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            deviceInfo = Map<String, dynamic>.from(data);
            notifyListeners();
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
    _stalenessTimer?.cancel();
    _stalenessTimer = null;
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
    } catch (e) {
      debugPrint('Failed to load bug report: $e');
    }
    return null;
  }

  /// Load recent bug reports list.
  Future<List<Map<String, dynamic>>> loadPastReports() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('reports')
          .orderByChild('createdAt')
          .limitToLast(20)
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final reports = data.values
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        reports.sort(
          (a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''),
        );
        return reports;
      }
    } catch (e) {
      debugPrint('Failed to load past reports: $e');
    }
    return [];
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
