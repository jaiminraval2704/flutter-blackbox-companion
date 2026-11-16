import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../dashboard/data/firebase_service.dart';
import '../../../../core/widgets/glass_container.dart';

class SupportScreen extends StatefulWidget {
  final bool fromDashboard;
  const SupportScreen({super.key, this.fromDashboard = false});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String _upiId = 'jaiminraval2704-2@oksbi';
  static const String _payeeName = 'Jaimin Raval';
  static const String _portfolioUrl = 'https://jaimin-raval-portfolio.web.app/';
  static const String _githubUrl = 'https://github.com/jaiminraval2704';

  int _selectedAmount = 100;
  bool _isCustomAmount = false;
  final TextEditingController _customAmountController = TextEditingController();
  bool _copied = false;
  JSFunction? _popStateCallback;

  final List<Map<String, dynamic>> _tiers = [
    {'amount': 50, 'emoji': '☕', 'label': 'Coffee'},
    {'amount': 100, 'emoji': '🍕', 'label': 'Snack'},
    {'amount': 250, 'emoji': '🚀', 'label': 'Supporter'},
    {'amount': 500, 'emoji': '💖', 'label': 'Sponsor'},
  ];

  @override
  void initState() {
    super.initState();
    try {
      _popStateCallback = ((web.Event event) {
        if (!mounted) return;
        final currentPath = web.window.location.pathname;
        if (!currentPath.contains('/support')) {
          _handleBack();
        }
      }).toJS;
      web.window.addEventListener('popstate', _popStateCallback);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_popStateCallback != null) {
      try {
        web.window.removeEventListener('popstate', _popStateCallback);
      } catch (_) {}
    }
    _customAmountController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (!mounted) return;
    final currentPath = web.window.location.pathname;
    if (currentPath == '/' || currentPath == '/connection') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/connection',
        (route) => false,
      );
      return;
    }
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

  void _openUrl(String url) {
    try {
      web.window.open(url, '_blank');
    } catch (_) {}
  }

  String _getUpiPayload() {
    final amount = _isCustomAmount
        ? (int.tryParse(_customAmountController.text.trim()) ?? 100)
        : _selectedAmount;
    final encodedName = Uri.encodeComponent(_payeeName);
    final encodedNote = Uri.encodeComponent('Support Flutter BlackBox');
    return 'upi://pay?pa=$_upiId&pn=$encodedName&am=$amount&cu=INR&tn=$encodedNote';
  }

  void _copyUpiId() {
    Clipboard.setData(const ClipboardData(text: _upiId));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
            SizedBox(width: 8),
            Text('UPI ID copied to clipboard! (jaiminraval2704-2@oksbi)'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _payViaUpiApp() {
    final payload = _getUpiPayload();
    try {
      web.window.location.href = payload;
    } catch (e) {
      _copyUpiId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAmount = _isCustomAmount
        ? (int.tryParse(_customAmountController.text.trim()) ?? 100)
        : _selectedAmount;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080C14),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF080C14), Color(0xFF0F172A)],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildHeroBanner(),
                          const SizedBox(height: 32),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 760) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: _buildCreatorCard()),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 6,
                                      child: _buildUpiPaymentCard(currentAmount),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildCreatorCard(),
                                    const SizedBox(height: 24),
                                    _buildUpiPaymentCard(currentAmount),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 32),
                          _buildInternationalSupportCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            tooltip: 'Go Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: _handleBack,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support Developer',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Help keep Flutter BlackBox free & open-source',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _openUrl(_portfolioUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Portfolio', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[300],
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            icon: Icon(Icons.home_rounded, size: 16, color: Colors.grey[500]),
            label: Text('Home', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEC4899).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('❤️', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'COMMUNITY SPONSORSHIP',
                style: TextStyle(
                  color: Color(0xFFF472B6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Fuel the Development of BlackBox',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Flutter BlackBox is built with passion to save developers hundreds of hours debugging apps. Direct support helps maintain the packages, infrastructure, and companion web dashboard.',
            style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'JR',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaimin Raval',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Flutter Developer & Creator',
                      style: TextStyle(color: const Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'About the Creator',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hey there! I am Jaimin Raval, a passionate mobile software engineer. I created Flutter BlackBox to give Flutter developers real-time, in-app and remote companion visibility into their network payloads, logs, crashes, and performance.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Your contributions help cover Firebase Realtime Database servers, domain hosting, and ongoing open-source maintenance.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(_portfolioUrl),
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('View Portfolio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF080C14),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(_githubUrl),
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('GitHub'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Developer Support • 100% goes to the creator',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiPaymentCard(int currentAmount) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF34D399), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay via UPI (Instant & 0% Fee)',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Scan with Google Pay, PhonePe, Paytm, or BHIM',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // UPI ID Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI ID / VPA',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _upiId,
                        style: GoogleFonts.firaCode(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _copyUpiId,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 13,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy ID', style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF080C14),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preset amount chips
          Text(
            'Select Amount',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tiers.map((t) {
                final isSelected = !_isCustomAmount && _selectedAmount == t['amount'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _isCustomAmount = false;
                      _selectedAmount = t['amount'] as int;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t['emoji'], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '₹${t['amount']} ${t['label']}',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              InkWell(
                onTap: () {
                  setState(() {
                    _isCustomAmount = true;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isCustomAmount
                        ? const Color(0xFFEC4899).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isCustomAmount
                          ? const Color(0xFFEC4899)
                          : Colors.white.withValues(alpha: 0.1),
                      width: _isCustomAmount ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✏️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: _isCustomAmount ? const Color(0xFFEC4899) : Colors.white,
                          fontSize: 12,
                          fontWeight: _isCustomAmount ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isCustomAmount) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                hintText: 'Enter custom amount in INR',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Dynamic QR Code Presentation
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _getUpiPayload(),
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF080C14),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF080C14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Scan to Pay ₹$currentAmount to Jaimin Raval',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _payViaUpiApp,
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text('Open in UPI App (₹$currentAmount)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34D399),
                      foregroundColor: const Color(0xFF080C14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternationalSupportCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF818CF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.public_rounded, color: Color(0xFF818CF8), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outside India? Global Support',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'If UPI is not supported in your region, support via GitHub Sponsors or check out Jaimin\'s portfolio projects.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _openUrl(_githubUrl),
            icon: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
            label: const Text('Star on GitHub'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
