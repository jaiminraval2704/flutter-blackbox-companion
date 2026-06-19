import 'dart:math';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../widgets/glass_container.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with TickerProviderStateMixin {
  late String _sessionId;
  bool _hasNavigated = false;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;
  List<Map<String, dynamic>> _sessionHistory = [];
  List<Map<String, dynamic>> _pastReports = [];
  bool _isLoadingHistory = true;
  int _historyTab = 0; // 0 = Sessions, 1 = Reports

  @override
  void initState() {
    super.initState();

    final Uri uri = Uri.base;
    final watchId = uri.queryParameters['watch'];

    if (watchId != null && watchId.isNotEmpty) {
      _sessionId = watchId;
      FirebaseService.instance.startListening(watchId, viewOnly: true);
    } else {
      String? savedSessionId;
      try {
        savedSessionId = web.window.localStorage.getItem('active_session_id');
      } catch (_) {}

      _sessionId =
          savedSessionId ?? (100000 + Random().nextInt(900000)).toString();
      FirebaseService.instance.startListening(_sessionId);
    }

    FirebaseService.instance.addListener(_onConnectionStatusChanged);
    _loadHistory();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadHistory() async {
    final history = await FirebaseService.instance.loadSessionHistory();
    final reports = await FirebaseService.instance.loadPastReports();
    if (mounted) {
      setState(() {
        _sessionHistory = history;
        _pastReports = reports;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    FirebaseService.instance.removeListener(_onConnectionStatusChanged);
    super.dispose();
  }

  void _onConnectionStatusChanged() {
    if (FirebaseService.instance.isConnected && mounted && !_hasNavigated) {
      _hasNavigated = true;
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _connectToSession(String sessionId) {
    FirebaseService.instance.startListening(sessionId, viewOnly: true);
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF080C14),
                  Color(0xFF0A1628),
                  Color(0xFF0F172A),
                  Color(0xFF0A0E1A),
                ],
              ),
            ),
          ),
          // Subtle accent glow behind the card
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: MediaQuery.of(context).size.width * 0.5 - 150,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF38BDF8,
                        ).withValues(alpha: 0.08 * _pulseAnim.value),
                        blurRadius: 120,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: screenWidth > 900
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConnectCard(),
                            const SizedBox(width: 24),
                            _buildHistoryCard(),
                          ],
                        )
                      : Column(
                          children: [
                            _buildConnectCard(),
                            const SizedBox(height: 24),
                            _buildHistoryCard(),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(48),
      borderRadius: 24,
      blur: 16,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      borderColor: Colors.white.withValues(alpha: 0.08),
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.hub_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            'BlackBox Companion',
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your mobile app to debug in real-time on your desktop',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Enter this code in your mobile app',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  const Color(0xFF818CF8).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
            ),
            child: SelectableText(
              _sessionId,
              style: GoogleFonts.firaCode(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF38BDF8),
                letterSpacing: 12,
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Animated waiting indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.grey[500]!),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting for mobile app to connect...',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      blur: 16,
      backgroundColor: Colors.white.withValues(alpha: 0.03),
      borderColor: Colors.white.withValues(alpha: 0.06),
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _tabButton(0, Icons.history_rounded, 'Sessions'),
              const SizedBox(width: 12),
              _tabButton(1, Icons.bug_report_rounded, 'Reports'),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_historyTab == 0)
            _buildSessionsList()
          else
            _buildReportsList(),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String title) {
    final isSelected = _historyTab == index;
    return GestureDetector(
      onTap: () => setState(() => _historyTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF38BDF8) : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[500],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_sessionHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 36, color: Colors.grey[700]),
              const SizedBox(height: 8),
              Text(
                'No past sessions yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Sessions will appear here after you disconnect',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _sessionHistory
          .take(8)
          .map((s) => _sessionHistoryItem(s))
          .toList(),
    );
  }

  Widget _buildReportsList() {
    if (_pastReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.bug_report_outlined,
                size: 36,
                color: Colors.grey[700],
              ),
              const SizedBox(height: 8),
              Text(
                'No bug reports yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Generate reports from the dashboard',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _pastReports.take(8).map((r) => _reportHistoryItem(r)).toList(),
    );
  }

  Widget _reportHistoryItem(Map<String, dynamic> report) {
    final title = report['title'] ?? 'Bug Report';
    final timestamp = report['createdAt'] ?? '';
    final reportId = report['reportId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.pushNamed(context, '/report', arguments: reportId);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        _formatSessionDate(timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
  }

  Widget _sessionHistoryItem(Map<String, dynamic> session) {
    final timestamp = session['timestamp'] ?? '';
    final device = session['device'] ?? 'Unknown';
    final platform = session['platform'] ?? '';
    final requestCount = session['requestCount'] ?? 0;
    final errorCount = session['errorCount'] ?? 0;
    final duration = session['durationSeconds'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // View this past session as read-only
            final sessionId = session['sessionId'];
            if (sessionId != null) {
              _connectToSession(sessionId);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                // Device icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    platform.toString().toLowerCase().contains('ios')
                        ? Icons.phone_iphone_rounded
                        : Icons.phone_android_rounded,
                    size: 16,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatSessionDate(timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$requestCount req',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    if (errorCount > 0)
                      Text(
                        '$errorCount errors',
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 11,
                        ),
                      )
                    else
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSessionDate(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }
}
