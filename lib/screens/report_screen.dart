import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../widgets/glass_container.dart';

class ReportScreen extends StatefulWidget {
  final String reportId;
  final bool fromDashboard;
  const ReportScreen({
    super.key,
    required this.reportId,
    this.fromDashboard = false,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await FirebaseService.instance.loadBugReport(
        widget.reportId,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
          if (report == null) _error = 'Report not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load report: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080C14), Color(0xFF0F172A)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _buildReport(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFF87171),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFF87171), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (widget.fromDashboard) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/dashboard',
                  (route) => false,
                );
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final r = _report!;
    final deviceInfo = r['deviceInfo'] as Map?;
    final networkList =
        (r['recentNetworkRequests'] as List?)?.cast<Map>() ?? [];
    final logList = (r['recentLogs'] as List?)?.cast<Map>() ?? [];
    final crashList = (r['crashes'] as List?)?.cast<Map>() ?? [];
    final navList = (r['navigationHistory'] as List?)?.cast<Map>() ?? [];

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
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
                  Icons.bug_report_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['title'] ?? 'Bug Report',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Generated ${_formatDate(r['createdAt'])}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (widget.fromDashboard) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/dashboard',
                      (route) => false,
                    );
                  } else {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  }
                },
                icon: Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: Colors.grey[500],
                ),
                label: Text('Home', style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Notes
              if (r['notes'] != null && (r['notes'] as String).isNotEmpty) ...[
                _reportSection(
                  'Notes',
                  Icons.note_alt_rounded,
                  const Color(0xFF38BDF8),
                ),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    r['notes'],
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Device Info
              if (deviceInfo != null) ...[
                _reportSection(
                  'Device Info',
                  Icons.phone_android_rounded,
                  const Color(0xFF818CF8),
                ),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: deviceInfo.entries
                        .map((e) => _infoPill(e.key, e.value.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Crashes
              if (crashList.isNotEmpty) ...[
                _reportSection(
                  'Crashes (${crashList.length})',
                  Icons.error_rounded,
                  const Color(0xFFF87171),
                ),
                ...crashList.map(
                  (c) => _crashCard(Map<String, dynamic>.from(c)),
                ),
                const SizedBox(height: 24),
              ],
              // Navigation History
              if (navList.isNotEmpty) ...[
                _reportSection(
                  'User Journey (${navList.length})',
                  Icons.route_rounded,
                  const Color(0xFFFBBF24),
                ),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: navList.reversed
                        .map((n) => _navItem(Map<String, dynamic>.from(n)))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Network Requests
              if (networkList.isNotEmpty) ...[
                _reportSection(
                  'Recent Network (${networkList.length})',
                  Icons.swap_vert_rounded,
                  const Color(0xFF34D399),
                ),
                ...networkList.map(
                  (n) => _networkCard(Map<String, dynamic>.from(n)),
                ),
                const SizedBox(height: 24),
              ],
              // Logs
              if (logList.isNotEmpty) ...[
                _reportSection(
                  'Recent Logs (${logList.length})',
                  Icons.terminal_rounded,
                  const Color(0xFF38BDF8),
                ),
                ...logList.map((l) => _logCard(Map<String, dynamic>.from(l))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportSection(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _crashCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c['message'] ?? '',
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (c['stackTrace'] != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                c['stackTrace'].toString(),
                style: GoogleFonts.firaCode(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
                maxLines: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navItem(Map<String, dynamic> n) {
    final action = n['action'] ?? '';
    final route = n['route'] ?? '';
    final icon = action == 'push'
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;
    final color = action == 'push'
        ? const Color(0xFF34D399)
        : const Color(0xFFFBBF24);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            '$action ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              route,
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
          ),
          if (n['timestamp'] != null)
            Text(
              _formatTime(n['timestamp']),
              style: TextStyle(color: Colors.grey[700], fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _networkCard(Map<String, dynamic> n) {
    final req = n['request'] is Map
        ? Map<String, dynamic>.from(n['request'] as Map)
        : <String, dynamic>{};
    final res = n['response'] is Map
        ? Map<String, dynamic>.from(n['response'] as Map)
        : <String, dynamic>{};
    final method = req['method'] ?? 'GET';
    final url = req['url'] ?? '';
    final status = res['statusCode'];
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 2),
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
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: GoogleFonts.firaCode(
                color: Colors.grey[400],
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status != null)
            Text(
              '$status',
              style: TextStyle(
                color: status is int && status >= 400
                    ? const Color(0xFFF87171)
                    : const Color(0xFF34D399),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> l) {
    final level = (l['level'] ?? 'info').toString().toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _levelColor(level).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level.length > 4 ? level.substring(0, 4) : level,
              style: TextStyle(
                color: _levelColor(level),
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l['message'] ?? '',
              style: GoogleFonts.firaCode(
                color: Colors.grey[400],
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _methodColor(String m) {
    switch (m.toUpperCase()) {
      case 'GET':
        return const Color(0xFF38BDF8);
      case 'POST':
        return const Color(0xFF34D399);
      case 'PUT':
        return const Color(0xFFFBBF24);
      case 'DELETE':
        return const Color(0xFFF87171);
      default:
        return Colors.grey;
    }
  }

  Color _levelColor(String l) {
    switch (l) {
      case 'ERROR':
        return const Color(0xFFF87171);
      case 'WARNING':
        return const Color(0xFFFBBF24);
      case 'INFO':
        return const Color(0xFF38BDF8);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic d) {
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(dynamic t) {
    try {
      final dt = DateTime.parse(t.toString());
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
