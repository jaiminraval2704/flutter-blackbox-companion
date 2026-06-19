import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Map<String, dynamic>? _selectedNetworkRequest;
  int _networkDetailTab = 0;
  final TextEditingController _networkSearchController =
      TextEditingController();
  final TextEditingController _logSearchController = TextEditingController();
  final Set<String> _activeLogLevels = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
  String _networkMethodFilter = 'ALL';
  late DateTime _connectedAt;
  bool _notificationsEnabled = false;
  Timer? _rebuildTimer;

  @override
  void initState() {
    super.initState();
    _connectedAt = DateTime.now();
    // Listen for crashes to show browser notifications
    FirebaseService.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    _networkSearchController.dispose();
    _logSearchController.dispose();
    FirebaseService.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  int _lastCrashCount = 0;
  int _lastErrorLogCount = 0;

  void _onDataChanged() {
    // Throttle rebuilds — at most once per 300ms to prevent jank from
    // rapid-fire Firebase events (every log/network/crash triggers this).
    _rebuildTimer ??= Timer(const Duration(milliseconds: 300), () {
      _rebuildTimer = null;
      if (mounted) setState(() {});
    });

    final currentCrashCount = FirebaseService.instance.crashes.length;

    // Browser notification ONLY for NEW crashes
    if (_notificationsEnabled &&
        currentCrashCount > _lastCrashCount &&
        currentCrashCount > 0) {
      final latestCrash = FirebaseService.instance.crashes.first;
      _showBrowserNotification(
        'BlackBox: Crash Detected',
        latestCrash['message']?.toString() ?? 'An error occurred in your app',
      );
    }
    _lastCrashCount = currentCrashCount;

    // Browser notification on error log
    final errorLogs = FirebaseService.instance.logs
        .where((l) => (l['level'] ?? '').toString().toUpperCase() == 'ERROR')
        .length;
    if (_notificationsEnabled && errorLogs > _lastErrorLogCount) {
      final latestError = FirebaseService.instance.logs.firstWhere(
        (l) => (l['level'] ?? '').toString().toUpperCase() == 'ERROR',
        orElse: () => {},
      );
      if (latestError.isNotEmpty) {
        _showBrowserNotification(
          'BlackBox: Error Log',
          latestError['message']?.toString() ?? 'Error logged',
        );
      }
    }
    _lastErrorLogCount = errorLogs;
  }

  void _showBrowserNotification(String title, String body) {
    try {
      web.Notification(
        title,
        web.NotificationOptions(body: body, icon: '/icons/Icon-192.png'),
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      // web.Notification.requestPermission() returns a JSPromise, so we await it
      final permission = await web.Notification.requestPermission().toDart;
      if (mounted) {
        setState(() {
          _notificationsEnabled = permission.toDart == 'granted';
        });
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  // ── Helper Methods ──────────────────────────────────────────────────

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF38BDF8);
      case 'POST':
        return const Color(0xFF34D399);
      case 'PUT':
        return const Color(0xFFFBBF24);
      case 'PATCH':
        return const Color(0xFFA78BFA);
      case 'DELETE':
        return const Color(0xFFF87171);
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(int? code) {
    if (code == null) return Colors.grey;
    if (code < 300) return const Color(0xFF34D399);
    if (code < 400) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  Color _durationColor(int ms) {
    if (ms < 200) return const Color(0xFF34D399);
    if (ms < 500) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0)
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  Map<String, dynamic> _getNetworkStats() {
    final requests = FirebaseService.instance.networkRequests;
    if (requests.isEmpty) {
      return {
        'total': 0,
        'success': 0,
        'errors': 0,
        'avgTime': 0,
        'successRate': 0.0,
      };
    }
    int total = requests.length;
    int success = 0;
    int errors = 0;
    int totalTime = 0;
    int withTime = 0;

    for (final req in requests) {
      final res = req['response'];
      if (res is Map) {
        final code = res['statusCode'];
        if (code is int) {
          if (code < 400) {
            success++;
          } else {
            errors++;
          }
        }
        final dur = res['durationMs'];
        if (dur is int) {
          totalTime += dur;
          withTime++;
        }
      }
    }
    return {
      'total': total,
      'success': success,
      'errors': errors,
      'avgTime': withTime > 0 ? (totalTime / withTime).round() : 0,
      'successRate': total > 0 ? (success / total * 100) : 0.0,
    };
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeaderBar(),
                Expanded(child: _buildContentArea()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Bar ──────────────────────────────────────────────────────

  Widget _buildHeaderBar() {
    final uptime = DateTime.now().difference(_connectedAt);
    final stats = _getNetworkStats();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Connection status
          _PulsingDot(
            color: FirebaseService.instance.isConnected
                ? const Color(0xFF34D399)
                : const Color(0xFFF87171),
          ),
          const SizedBox(width: 10),
          Text(
            FirebaseService.instance.isConnected
                ? (FirebaseService.instance.isViewOnly
                      ? 'Viewing'
                      : 'Connected')
                : 'Disconnected',
            style: TextStyle(
              color: FirebaseService.instance.isConnected
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          _headerDivider(),
          // Session uptime
          _UptimeWidget(connectedAt: _connectedAt),
          _headerDivider(),
          // Quick stats
          Icon(Icons.swap_vert_rounded, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            '${stats['total']} requests',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          // Crash count
          if (FirebaseService.instance.crashes.isNotEmpty) ...[
            _headerDivider(),
            Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: const Color(0xFFF87171),
            ),
            const SizedBox(width: 6),
            Text(
              '${FirebaseService.instance.crashes.length} crashes',
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
            ),
          ],
          const Spacer(),
          // Notification toggle
          IconButton(
            tooltip: _notificationsEnabled
                ? 'Notifications ON'
                : 'Enable notifications',
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 18,
              color: _notificationsEnabled
                  ? const Color(0xFFFBBF24)
                  : Colors.grey[600],
            ),
            onPressed: () {
              if (_notificationsEnabled) {
                setState(() => _notificationsEnabled = false);
              } else {
                _requestNotificationPermission();
              }
            },
          ),
          // Past Reports
          IconButton(
            tooltip: 'View past reports',
            icon: Icon(
              Icons.folder_open_rounded,
              size: 18,
              color: Colors.grey[500],
            ),
            onPressed: _showPastReportsDialog,
          ),
          // Share session
          IconButton(
            tooltip: 'Share live session',
            icon: Icon(Icons.share_rounded, size: 18, color: Colors.grey[500]),
            onPressed: _shareSession,
          ),
          // Generate bug report
          _buildReportButton(),
          const SizedBox(width: 8),
          // Session ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Session: ${FirebaseService.instance.sessionId ?? '—'}',
              style: GoogleFonts.firaCode(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Disconnect button
          if (!FirebaseService.instance.isViewOnly)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: _handleDisconnect,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Disconnect', style: TextStyle(fontSize: 13)),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                FirebaseService.instance.disconnect();
                Navigator.pushReplacementNamed(context, '/');
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Exit', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _headerDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 20,
      color: Colors.white10,
    );
  }

  void _handleDisconnect() async {
    // Save session summary before disconnecting
    final uptime = DateTime.now().difference(_connectedAt);
    await FirebaseService.instance.saveSessionSummary(uptime: uptime);
    if (mounted) {
      FirebaseService.instance.disconnect();
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _shareSession() {
    final sessionId = FirebaseService.instance.sessionId;
    if (sessionId == null) return;
    final url = 'https://flutter-blackbox-companion.web.app/?watch=$sessionId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session link copied to clipboard! Share it with your team.',
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _showBugReportDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF87171).withValues(alpha: 0.15),
                const Color(0xFFFBBF24).withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF87171).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bug_report_rounded,
                size: 16,
                color: Color(0xFFF87171),
              ),
              const SizedBox(width: 6),
              Text(
                'Report Bug',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBugReportDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.bug_report_rounded,
              color: Color(0xFFF87171),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Generate Bug Report',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will capture your current session data and generate a shareable link.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Bug Title',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report will include:',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _reportIncludesItem(
                      'Last 10 network requests',
                      FirebaseService.instance.networkRequests.length,
                    ),
                    _reportIncludesItem(
                      'Last 20 logs',
                      FirebaseService.instance.logs.length,
                    ),
                    _reportIncludesItem(
                      'Crashes',
                      FirebaseService.instance.crashes.length,
                    ),
                    _reportIncludesItem(
                      'Navigation history',
                      FirebaseService.instance.navigationEvents.length,
                    ),
                    if (FirebaseService.instance.deviceInfo != null)
                      _reportIncludesItem('Device info', 1),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _generateReport(titleController.text, notesController.text);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Widget _reportIncludesItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: count > 0 ? const Color(0xFF34D399) : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport(String title, String notes) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating bug report...')));

    final reportId = await FirebaseService.instance.generateBugReport(
      title: title.isNotEmpty ? title : null,
      notes: notes.isNotEmpty ? notes : null,
    );

    if (reportId != null && mounted) {
      // Show success dialog with shareable link
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF34D399),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Generated!',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your bug report has been saved. Share the report ID with your team.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        'Report ID: $reportId',
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFF38BDF8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reportId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report ID copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/report',
                  arguments: {'reportId': reportId, 'fromDashboard': true},
                );
              },
              child: const Text('View Report'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showPastReportsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(32),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading reports...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final reports = await FirebaseService.instance.loadPastReports();
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      _showReportsListDialog(reports);
    }
  }

  void _showReportsListDialog(List<Map<String, dynamic>> reports) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              color: Color(0xFF38BDF8),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Past Bug Reports',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: reports.isEmpty
              ? Center(
                  child: Text(
                    'No past reports found.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final title = report['title'] ?? 'Bug Report';
                    final timestamp = report['createdAt'] ?? '';
                    final reportId = report['reportId'] ?? '';

                    // Format date locally
                    String dateStr = timestamp;
                    try {
                      final dt = DateTime.parse(timestamp.toString()).toLocal();
                      dateStr =
                          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(
                              context,
                              '/report',
                              arguments: {
                                'reportId': reportId,
                                'fromDashboard': true,
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF87171,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.bug_report_rounded,
                                    size: 16,
                                    color: Color(0xFFF87171),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'BlackBox',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Global Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search anywhere...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[500],
                  size: 16,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          _sidebarItem(0, Icons.dashboard_rounded, 'Overview'),
          _sidebarItem(1, Icons.network_check_rounded, 'Network'),
          _sidebarItem(2, Icons.terminal_rounded, 'Logs'),
          _sidebarItem(3, Icons.speed_rounded, 'Performance'),
          _sidebarItem(4, Icons.perm_device_information_rounded, 'Device Info'),
          _sidebarItem(5, Icons.bug_report_rounded, 'Crashes'),
          _sidebarItem(6, Icons.route_rounded, 'Journey'),
          const Spacer(),
          // Export HAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildExportButton(),
          ),
          // Keyboard shortcuts hint
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Ctrl+1-3: Tabs  •  Ctrl+K: Search',
              style: TextStyle(color: Colors.grey[800], fontSize: 10),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(
              'Powered by BlackBox',
              style: TextStyle(color: Colors.grey[700], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF38BDF8)
                      : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[500],
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _exportHAR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(
                'Export HAR',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportHAR() {
    final requests = FirebaseService.instance.networkRequests;
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No network requests to export')),
      );
      return;
    }

    final har = {
      'log': {
        'version': '1.2',
        'creator': {'name': 'BlackBox Companion', 'version': '1.0'},
        'entries': requests.map((req) {
          final request = req['request'] ?? {};
          final response = req['response'] ?? {};
          return {
            'startedDateTime':
                req['timestamp'] ?? DateTime.now().toIso8601String(),
            'request': {
              'method': request['method'] ?? 'GET',
              'url': request['url'] ?? '',
              'headers': _convertHeaders(request['headers']),
              'postData': {'text': request['body']?.toString() ?? ''},
            },
            'response': {
              'status': response['statusCode'] ?? 0,
              'headers': _convertHeaders(response['headers']),
              'content': {'text': response['body']?.toString() ?? ''},
            },
            'time': response['durationMs'] ?? 0,
          };
        }).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(har);
    final bytes = utf8.encode(jsonString);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'blackbox_export.har';
    anchor.click();
    web.URL.revokeObjectURL(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HAR file exported successfully!')),
    );
  }

  List<Map<String, String>> _convertHeaders(dynamic headers) {
    if (headers is Map) {
      return headers.entries
          .map((e) => {'name': e.key.toString(), 'value': e.value.toString()})
          .toList();
    }
    return [];
  }

  // ── Content Area ──────────────────────────────────────────────────────

  Widget _buildContentArea() {
    return Container(
      color: const Color(0xFF080C14),
      child: ListenableBuilder(
        listenable: FirebaseService.instance,
        builder: (context, child) {
          if (!FirebaseService.instance.isConnected) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Color(0xFFF87171),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Disconnected from mobile app',
                    style: TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The mobile app has ended the session',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      FirebaseService.instance.disconnect();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    icon: const Icon(Icons.hub_rounded, size: 18),
                    label: const Text('New Connection'),
                  ),
                ],
              ),
            );
          }

          if (_selectedIndex == 0) return _buildOverviewView();
          if (_selectedIndex == 1) return _buildNetworkView();
          if (_selectedIndex == 2) return _buildLogsView();
          if (_selectedIndex == 3) return _buildPerformanceView();
          if (_selectedIndex == 4) return _buildDeviceInfoView();
          if (_selectedIndex == 5) return _buildCrashesView();
          return _buildJourneyView();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── NETWORK VIEW ────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildNetworkView() {
    final allRequests = FirebaseService.instance.networkRequests;
    final stats = _getNetworkStats();

    final searchQuery = _networkSearchController.text.toLowerCase();
    final requests = allRequests.where((req) {
      final request = req['request'] ?? {};
      final response = req['response'] ?? {};
      final url = (request['url'] ?? '').toString().toLowerCase();
      final method = (request['method'] ?? 'GET').toString().toUpperCase();
      final statusCode = response['statusCode']?.toString() ?? '';

      if (_networkMethodFilter != 'ALL' && method != _networkMethodFilter)
        return false;
      if (searchQuery.isNotEmpty &&
          !url.contains(searchQuery) &&
          !method.toLowerCase().contains(searchQuery) &&
          !statusCode.contains(searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Total Requests',
                  value: '${stats['total']}',
                  icon: Icons.swap_vert_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Success Rate',
                  value:
                      '${(stats['successRate'] as double).toStringAsFixed(1)}%',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Avg Response',
                  value: '${stats['avgTime']}ms',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Errors',
                  value: '${stats['errors']}',
                  icon: Icons.error_outline_rounded,
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
        ),
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: _searchField(
                  _networkSearchController,
                  'Search by URL, method, or status...',
                ),
              ),
              const SizedBox(width: 12),
              for (final method in ['ALL', 'GET', 'POST', 'PUT', 'DELETE'])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _filterChip(
                    method,
                    _networkMethodFilter == method,
                    () {
                      setState(() => _networkMethodFilter = method);
                    },
                  ),
                ),
              const SizedBox(width: 12),
              _miniButton(Icons.delete_sweep_rounded, 'Clear', () {
                setState(() {
                  FirebaseService.instance.networkRequests.clear();
                  _selectedNetworkRequest = null;
                });
              }),
            ],
          ),
        ),
        // Network list + detail panel
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Text(
                    'No requests match your filters',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: _selectedNetworkRequest != null ? 3 : 1,
                      child: _buildNetworkList(requests),
                    ),
                    if (_selectedNetworkRequest != null)
                      Expanded(flex: 2, child: _buildNetworkDetails()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildNetworkList(List<Map<String, dynamic>> requests) {
    return ListView.builder(
      itemCount: requests.length,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemBuilder: (context, index) {
        final req = requests[index];
        final requestData = req['request'] ?? {};
        final responseData = req['response'] ?? {};
        final method = (requestData['method'] ?? 'GET')
            .toString()
            .toUpperCase();
        final url = requestData['url'] ?? '';
        final statusCode = responseData['statusCode'];
        final durationMs = responseData['durationMs'];
        final isSelected = _selectedNetworkRequest == req;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedNetworkRequest = req),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _methodColor(method).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        method,
                        style: TextStyle(
                          color: _methodColor(method),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (req['deviceName'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF82AAFF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_android_rounded,
                              size: 10,
                              color: Color(0xFF82AAFF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              req['deviceName'],
                              style: const TextStyle(
                                color: Color(0xFF82AAFF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        url,
                        style: GoogleFonts.firaCode(
                          color: Colors.grey[300],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (durationMs != null)
                      Container(
                        width: 64,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${durationMs}ms',
                          style: TextStyle(
                            color: _durationColor(
                              durationMs is int ? durationMs : 0,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        statusCode != null ? '$statusCode' : '···',
                        style: TextStyle(
                          color: _statusColor(
                            statusCode is int ? statusCode : null,
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetworkDetails() {
    final req = _selectedNetworkRequest!;
    final requestData = req['request'] ?? {};
    final responseData = req['response'] ?? {};
    final tabs = ['Headers', 'Body', 'Response', 'Timing'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _methodColor(
                      requestData['method'] ?? 'GET',
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    requestData['method'] ?? 'GET',
                    style: TextStyle(
                      color: _methodColor(requestData['method'] ?? 'GET'),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requestData['url'] ?? '',
                    style: GoogleFonts.firaCode(
                      color: Colors.grey[300],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                  onPressed: () =>
                      setState(() => _selectedNetworkRequest = null),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isActive = _networkDetailTab == i;
                return GestureDetector(
                  onTap: () => setState(() => _networkDetailTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF38BDF8)
                            : Colors.grey[600],
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _buildDetailTabContent(requestData, responseData),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailTabContent(Map requestData, Map responseData) {
    switch (_networkDetailTab) {
      case 0:
        return [
          _sectionTitle('Request Headers'),
          _jsonView(requestData['headers'] ?? {}),
          const SizedBox(height: 16),
          _sectionTitle('Response Headers'),
          _jsonView(responseData['headers'] ?? {}),
        ];
      case 1:
        return [
          _sectionTitle('Request Body'),
          _jsonView(requestData['body'] ?? 'No body'),
        ];
      case 2:
        return [
          _sectionTitle('Status Code'),
          _detailBadge(
            responseData['statusCode']?.toString() ?? 'PENDING',
            _statusColor(
              responseData['statusCode'] is int
                  ? responseData['statusCode']
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Response Body'),
          _jsonView(responseData['body'] ?? 'No body'),
        ];
      case 3:
        return [
          _sectionTitle('Duration'),
          _detailBadge(
            responseData['durationMs'] != null
                ? '${responseData['durationMs']}ms'
                : 'N/A',
            responseData['durationMs'] != null
                ? _durationColor(
                    responseData['durationMs'] is int
                        ? responseData['durationMs']
                        : 0,
                  )
                : Colors.grey,
          ),
          const SizedBox(height: 16),
          _sectionTitle('URL'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              requestData['url']?.toString() ?? '',
              style: GoogleFonts.firaCode(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
        fontSize: 12,
      ),
    ),
  );

  Widget _detailBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // ── LOGS VIEW ─────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLogsView() {
    final allLogs = FirebaseService.instance.logs;
    final searchQuery = _logSearchController.text.toLowerCase();
    final logs = allLogs.where((log) {
      final level = (log['level'] ?? 'info').toString().toUpperCase();
      final message = (log['message'] ?? '').toString().toLowerCase();
      final tag = (log['tag'] ?? '').toString().toLowerCase();
      if (!_activeLogLevels.contains(level)) return false;
      if (searchQuery.isNotEmpty &&
          !message.contains(searchQuery) &&
          !tag.contains(searchQuery))
        return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: _searchField(_logSearchController, 'Search logs...'),
              ),
              const SizedBox(width: 12),
              for (final level in ['DEBUG', 'INFO', 'WARNING', 'ERROR'])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _logLevelChip(level),
                ),
              const SizedBox(width: 12),
              _miniButton(Icons.delete_sweep_rounded, 'Clear', () {
                setState(() => FirebaseService.instance.logs.clear());
              }),
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    'No logs match your filters',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final level = (log['level'] ?? 'info')
                        .toString()
                        .toUpperCase();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _logLevelColor(level).withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _logLevelColor(
                                level,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              level.length > 4 ? level.substring(0, 4) : level,
                              style: TextStyle(
                                color: _logLevelColor(level),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (log['deviceName'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF82AAFF,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_android_rounded,
                                    size: 10,
                                    color: Color(0xFF82AAFF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    log['deviceName'],
                                    style: const TextStyle(
                                      color: Color(0xFF82AAFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (log['tag'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log['tag'],
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: SelectableText(
                              log['message'] ?? '',
                              style: GoogleFonts.firaCode(
                                color: Colors.grey[300],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (log['timestamp'] != null)
                            Text(
                              _formatTimestamp(log['timestamp']),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      final dt = DateTime.parse(timestamp.toString());
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Color _logLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'DEBUG':
        return Colors.grey;
      case 'INFO':
        return const Color(0xFF38BDF8);
      case 'WARNING':
        return const Color(0xFFFBBF24);
      case 'ERROR':
        return const Color(0xFFF87171);
      default:
        return Colors.grey;
    }
  }

  Widget _logLevelChip(String level) {
    final isActive = _activeLogLevels.contains(level);
    return GestureDetector(
      onTap: () => setState(
        () => isActive
            ? _activeLogLevels.remove(level)
            : _activeLogLevels.add(level),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? _logLevelColor(level).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? _logLevelColor(level).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          level,
          style: TextStyle(
            color: isActive ? _logLevelColor(level) : Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── PERFORMANCE VIEW ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPerformanceView() {
    final data = FirebaseService.instance.performanceData;
    double currentFps = 0, avgFps = 0, minFps = 999;
    int dropCount = 0;

    if (data.isNotEmpty) {
      currentFps = (data.last['fps'] ?? 0).toDouble();
      double total = 0;
      for (final d in data) {
        final fps = (d['fps'] ?? 0).toDouble();
        total += fps;
        if (fps < minFps) minFps = fps;
        if (fps < 55) dropCount++;
      }
      avgFps = total / data.length;
    }
    if (minFps == 999) minFps = 0;

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['fps'] ?? 0).toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Current FPS',
                  value: currentFps.toStringAsFixed(0),
                  icon: Icons.speed_rounded,
                  color: currentFps >= 55
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Average FPS',
                  value: avgFps.toStringAsFixed(1),
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Min FPS',
                  value: minFps.toStringAsFixed(0),
                  icon: Icons.trending_down_rounded,
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Frame Drops',
                  value: '$dropCount',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFA78BFA),
                  subtitle: '< 55 FPS',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for performance data...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'FPS Timeline',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '60 FPS Target',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 30,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minY: 0,
                              maxY: 120,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    FlSpot(0, 60),
                                    FlSpot(data.length.toDouble(), 60),
                                  ],
                                  isCurved: false,
                                  color: const Color(
                                    0xFF34D399,
                                  ).withValues(alpha: 0.3),
                                  barWidth: 1,
                                  dotData: const FlDotData(show: false),
                                  dashArray: [6, 4],
                                ),
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF38BDF8),
                                      Color(0xFF818CF8),
                                    ],
                                  ),
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(
                                          0xFF38BDF8,
                                        ).withValues(alpha: 0.2),
                                        const Color(
                                          0xFF38BDF8,
                                        ).withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) =>
                                      touchedSpots.map((spot) {
                                        if (spot.barIndex == 0) return null;
                                        return LineTooltipItem(
                                          '${spot.y.toStringAsFixed(1)} FPS',
                                          GoogleFonts.firaCode(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── SHARED WIDGETS ────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _searchField(TextEditingController controller, String hint) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                setState(() {});
              },
              child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isActive, VoidCallback onTap) {
    final color = label == 'ALL' ? Colors.grey : _methodColor(label);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _miniButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── OVERVIEW VIEW ──────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildOverviewView() {
    final network = FirebaseService.instance.networkRequests;
    final logs = FirebaseService.instance.logs;
    final crashes = FirebaseService.instance.crashes;
    final perf = FirebaseService.instance.performanceData;

    int failedRequests = network
        .where(
          (r) => r['response'] != null && r['response']['statusCode'] >= 400,
        )
        .length;
    double successRate = network.isEmpty
        ? 100.0
        : ((network.length - failedRequests) / network.length) * 100;
    int avgFps = perf.isEmpty
        ? 60
        : (perf.map((e) => e['fps'] as num).reduce((a, b) => a + b) /
                  perf.length)
              .round();

    double healthScore = 100.0;
    healthScore -= (crashes.length * 20);
    healthScore -= (failedRequests * 2);
    if (avgFps < 40) healthScore -= 10;
    if (avgFps < 20) healthScore -= 20;
    healthScore = healthScore.clamp(0.0, 100.0);

    Color healthColor = const Color(0xFF34D399);
    if (healthScore < 70) healthColor = const Color(0xFFFBBF24);
    if (healthScore < 40) healthColor = const Color(0xFFF87171);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text(
          'Session Overview',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Health Score',
                          '${healthScore.toInt()}/100',
                          Icons.monitor_heart_rounded,
                          healthColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Crashes',
                          '${crashes.length}',
                          Icons.bug_report_rounded,
                          crashes.isEmpty
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'API Success',
                          '${successRate.toStringAsFixed(1)}%',
                          Icons.network_check_rounded,
                          successRate > 90
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Avg FPS',
                          '$avgFps',
                          Icons.speed_rounded,
                          avgFps >= 50
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _quickStatRow('Total Logs', logs.length.toString()),
                    const Divider(color: Colors.white12, height: 24),
                    _quickStatRow('Total APIs', network.length.toString()),
                    const Divider(color: Colors.white12, height: 24),
                    _quickStatRow(
                      'Navigation Events',
                      FirebaseService.instance.navigationEvents.length
                          .toString(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── DEVICE INFO VIEW ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDeviceInfoView() {
    final infoRaw = FirebaseService.instance.deviceInfo;
    if (infoRaw == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: const Color(0xFF6C63FF),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for device info...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    Map<String, dynamic> info = {};
    if (infoRaw is Map && infoRaw.isNotEmpty) {
      final firstVal = infoRaw.values.first;
      if (firstVal is Map) {
        info = Map<String, dynamic>.from(firstVal);
      } else {
        info = Map<String, dynamic>.from(infoRaw);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Information',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Real-time specifications and environment details of the connected device.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _PremiumDeviceCard(
              title: 'App Details',
              icon: Icons.apps_rounded,
              index: 0,
              gradientColors: const [Color(0xFF818CF8), Color(0xFF6366F1)],
              items: {
                'App Name': info['appName']?.toString() ?? '-',
                'Version': info['version']?.toString() ?? '-',
                'Build': info['buildNumber']?.toString() ?? '-',
              },
            ),
            _PremiumDeviceCard(
              title: 'Device & OS',
              icon: Icons.phone_android_rounded,
              index: 1,
              gradientColors: const [Color(0xFF34D399), Color(0xFF10B981)],
              items: {
                'Model': info['deviceModel']?.toString() ?? '-',
                'Platform': info['platform']?.toString() ?? '-',
                'OS Version': info['osVersion']?.toString() ?? '-',
                if (info['androidSdkInt'] != null)
                  'SDK Int': info['androidSdkInt'].toString(),
              },
            ),
            _PremiumDeviceCard(
              title: 'Display',
              icon: Icons.screenshot_rounded,
              index: 2,
              gradientColors: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              items: {
                'Screen Size': info['screenSize']?.toString() ?? '-',
                'Pixel Ratio': info['pixelRatio']?.toString() ?? '-',
                'Brightness': info['brightness']?.toString() ?? '-',
              },
            ),
            _PremiumDeviceCard(
              title: 'Environment',
              icon: Icons.public_rounded,
              index: 3,
              gradientColors: const [Color(0xFFF472B6), Color(0xFFEC4899)],
              items: {
                'Network': info['networkType']?.toString() ?? '-',
                'Locale': info['locale']?.toString() ?? '-',
                'Timezone': info['timezone']?.toString() ?? '-',
              },
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── CRASHES VIEW ──────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCrashesView() {
    final crashes = FirebaseService.instance.crashes;
    if (crashes.isEmpty) {
      return Center(
        child: Text(
          'No crashes recorded.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: crashes.length,
      itemBuilder: (context, index) {
        final crash = crashes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF87171).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF87171).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFF87171),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      crash['error'] ?? 'Unknown Error',
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (crash['deviceName'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF87171).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_android_rounded,
                            size: 10,
                            color: Color(0xFFF87171),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            crash['deviceName'],
                            style: const TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _formatTimestamp(crash['timestamp']),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _jsonView(crash['stackTrace'] ?? ''),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── JOURNEY VIEW ──────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildJourneyView() {
    final events = FirebaseService.instance.navigationEvents;
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No navigation events yet.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final ev = events[index];
        final isPush = ev['action'] == 'push';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(
                isPush ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                color: isPush
                    ? const Color(0xFF34D399)
                    : const Color(0xFFFBBF24),
                size: 16,
              ),
              const SizedBox(width: 12),
              Text(
                ev['route'] ?? 'Unknown Route',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (ev['arguments'] != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ev['arguments'].toString(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (ev['deviceName'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF82AAFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_android_rounded,
                        size: 10,
                        color: Color(0xFF82AAFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ev['deviceName'],
                        style: const TextStyle(
                          color: Color(0xFF82AAFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _formatTimestamp(ev['timestamp']),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _jsonView(dynamic data) {
    String text;
    try {
      if (data is String) {
        final parsed = jsonDecode(data);
        text = const JsonEncoder.withIndent('  ').convert(parsed);
      } else {
        text = const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (_) {
      text = data.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(right: 32),
            child: SelectableText(
              text,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: const Color(0xFF34D399),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: Icon(Icons.copy_rounded, color: Colors.grey[700], size: 16),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Dot Widget ────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * _controller.value),
                blurRadius: 6,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Uptime Widget ──────────────────────────────────────────────────

class _UptimeWidget extends StatefulWidget {
  final DateTime connectedAt;
  const _UptimeWidget({required this.connectedAt});

  @override
  State<_UptimeWidget> createState() => _UptimeWidgetState();
}

class _UptimeWidgetState extends State<_UptimeWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final uptime = DateTime.now().difference(widget.connectedAt);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          _formatDuration(uptime),
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
      ],
    );
  }
}

// ── Premium Device Card Widget ────────────────────────────────────────

class _PremiumDeviceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final int index;
  final List<Color> gradientColors;
  final Map<String, String> items;

  const _PremiumDeviceCard({
    required this.title,
    required this.icon,
    required this.index,
    required this.gradientColors,
    required this.items,
  });

  @override
  State<_PremiumDeviceCard> createState() => _PremiumDeviceCardState();
}

class _PremiumDeviceCardState extends State<_PremiumDeviceCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _enterAnimController;
  late Animation<double> _enterAnimation;

  @override
  void initState() {
    super.initState();
    _enterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _enterAnimation = CurvedAnimation(
      parent: _enterAnimController,
      curve: Curves.easeOutCubic,
    );
    
    // Staggered entrance based on index
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _enterAnimController.forward();
    });
  }

  @override
  void dispose() {
    _enterAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _enterAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _enterAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _enterAnimation.value)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 320,
          padding: const EdgeInsets.all(24),
          // ignore: deprecated_member_use
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -6.0 : 0.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered 
                ? widget.gradientColors[0].withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.gradientColors[0].withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.gradientColors[0].withValues(alpha: 0.2),
                          widget.gradientColors[1].withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.gradientColors[0].withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.gradientColors[0],
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...widget.items.entries.map((e) => _PremiumInfoRow(
                    label: e.key,
                    value: e.value,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PremiumInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
