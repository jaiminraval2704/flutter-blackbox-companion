import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../dashboard/data/firebase_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/utils/report_image_cache.dart';

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

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final sessionId = FirebaseService.instance.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/connection');
      }
    }
  }

  void _downloadScreenshot(Uint8List bytes) {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/png'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = 'blackbox_screenshot_${widget.reportId}.png';
      anchor.click();
      web.URL.revokeObjectURL(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot downloaded successfully!')),
      );
    } catch (e) {
      debugPrint('Failed to download screenshot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Go Back'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/connection',
                    (route) => false,
                  );
                },
                child: const Text('Go Home'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final r = _report!;
    final title = (r['title'] ?? r['bugTitle'] ?? 'Bug Report').toString();
    final severity = (r['severity'] ?? 'normal').toString().toUpperCase();
    final createdAt = r['createdAt'] ?? r['timestamp'] ?? '';
    final reportId = (r['reportId'] ?? widget.reportId).toString();
    final deviceInfo = (r['deviceInfo'] ?? r['device']) as Map?;
    final appInfo = (r['appInfo'] ?? r['app']) as Map?;
    final networkList =
        ((r['recentNetworkRequests'] ?? r['networkRequests'] ?? r['failedRequests']) as List?)?.cast<Map>() ?? [];
    final logList = ((r['recentLogs'] ?? r['logs']) as List?)?.cast<Map>() ?? [];
    final crashList = (r['crashes'] as List?)?.cast<Map>() ?? [];
    final navList = (r['navigationHistory'] ?? r['userJourney']) as List? ?? [];
    final screenshotBase64 = (r['screenshotBase64'] ?? r['screenshot']) as String?;

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
              IconButton(
                tooltip: 'Back to Dashboard',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                onPressed: _handleBack,
              ),
              const SizedBox(width: 8),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _severityColor(severity).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _severityColor(severity).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            severity,
                            style: TextStyle(
                              color: _severityColor(severity),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generated ${_formatDate(createdAt)} • ID: $reportId',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('Back', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[300],
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _toMarkdown(r)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report Markdown copied!')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Markdown', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[300],
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/connection',
                    (route) => false,
                  );
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
              // Screenshot Preview
              if (screenshotBase64 != null && screenshotBase64.isNotEmpty)
                _buildScreenshotCard(screenshotBase64),
              // Device & App Info
              if (deviceInfo != null || appInfo != null) ...[
                _reportSection(
                  'Device & Environment',
                  Icons.phone_android_rounded,
                  const Color(0xFF818CF8),
                ),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      if (deviceInfo != null)
                        ...deviceInfo.entries
                            .map((e) => _infoPill(e.key, e.value.toString())),
                      if (appInfo != null)
                        ...appInfo.entries
                            .map((e) => _infoPill('app_${e.key}', e.value.toString())),
                    ],
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
              // Navigation History / User Journey
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
                        .map((n) => _navItem(n))
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

  Widget _buildScreenshotCard(String base64Str) {
    final bytes = ReportImageCache.getBytes(widget.reportId, base64Str);

    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _reportSection('Screenshot', Icons.image_rounded, const Color(0xFF38BDF8)),
            ElevatedButton.icon(
              onPressed: () => _downloadScreenshot(bytes),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Download Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Tooltip(
                    message: 'Download screenshot image',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _downloadScreenshot(bytes),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                color: Color(0xFF38BDF8),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Download',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFEF4444);
      case 'HIGH':
        return const Color(0xFFF97316);
      case 'MEDIUM':
        return const Color(0xFFFBBF24);
      case 'LOW':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF818CF8);
    }
  }

  String _toMarkdown(Map<String, dynamic> r) {
    final title = r['title'] ?? r['bugTitle'] ?? 'Bug Report';
    final severity = (r['severity'] ?? 'NORMAL').toString().toUpperCase();
    final time = r['createdAt'] ?? r['timestamp'] ?? '';
    final notes = r['notes']?.toString() ?? '';
    final dev = (r['deviceInfo'] ?? r['device']) as Map?;
    final app = (r['appInfo'] ?? r['app']) as Map?;
    final nav = (r['navigationHistory'] ?? r['userJourney']) as List? ?? [];
    final net = ((r['recentNetworkRequests'] ?? r['networkRequests'] ?? r['failedRequests']) as List?)?.cast<Map>() ?? [];
    final crashes = (r['crashes'] as List?)?.cast<Map>() ?? [];

    final buffer = StringBuffer();
    buffer.writeln('## $title [$severity]');
    buffer.writeln();
    buffer.writeln('**Reported:** $time');
    if (dev != null) {
      buffer.writeln('**Device:** ${dev['deviceModel'] ?? dev['model'] ?? 'Unknown'} — ${dev['osVersion'] ?? dev['os'] ?? ''}');
    }
    if (app != null) {
      buffer.writeln('**App:** v${app['version'] ?? ''} (${app['buildNumber'] ?? ''})');
    }
    buffer.writeln();
    if (notes.isNotEmpty) {
      buffer.writeln('### Notes');
      buffer.writeln(notes);
      buffer.writeln();
    }
    if (nav.isNotEmpty) {
      buffer.writeln('### User Journey');
      for (final step in nav) {
        if (step is Map) {
          buffer.writeln('- ${step['action'] ?? ''} ${step['route'] ?? ''}');
        } else {
          buffer.writeln('- $step');
        }
      }
      buffer.writeln();
    }
    if (crashes.isNotEmpty) {
      buffer.writeln('### Crashes');
      for (final c in crashes) {
        buffer.writeln('- ${c['message']}');
      }
      buffer.writeln();
    }
    if (net.isNotEmpty) {
      buffer.writeln('### Network Requests');
      for (final n in net) {
        final req = n['request'] as Map?;
        final res = n['response'] as Map?;
        buffer.writeln('- ${req?['method'] ?? 'GET'} ${req?['url'] ?? ''} → ${res?['statusCode'] ?? ''}');
      }
      buffer.writeln();
    }
    return buffer.toString();
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

  Widget _navItem(dynamic n) {
    if (n is String) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: Color(0xFF34D399),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                n,
                style: TextStyle(color: Colors.grey[300], fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final map = n is Map ? Map<String, dynamic>.from(n) : <String, dynamic>{};
    final action = map['action']?.toString() ?? '';
    final route = (map['route'] ?? map['screen'] ?? map['name'] ?? '').toString();
    final icon = action == 'pop'
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;
    final color = action == 'pop'
        ? const Color(0xFFFBBF24)
        : const Color(0xFF34D399);
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
          if (map['timestamp'] != null)
            Text(
              _formatTime(map['timestamp']),
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
    final method = (req['method'] ?? n['method'] ?? 'GET').toString();
    final url = (req['url'] ?? n['url'] ?? '').toString();
    final status = res['statusCode'] ?? n['statusCode'] ?? n['status'];
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
