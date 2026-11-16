import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isAnnual = true;
  bool _isINR = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [_buildCurrencyToggle(), const SizedBox(width: 16)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            // Header
            Text(
              'Scale your debugging',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start for free. Upgrade when you need more power and team collaboration.',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Billing Toggle
            _buildBillingToggle(),
            const SizedBox(height: 48),

            // Pricing Cards
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildPricingCard(
                  title: 'Free',
                  description: 'Perfect for solo developers and side projects.',
                  priceMonthlyUSD: 0,
                  priceMonthlyINR: 0,
                  features: [
                    '100 logs per session',
                    '50 network requests per session',
                    '1 device connection',
                    '24h data retention',
                  ],
                  buttonText: 'Current Plan',
                  isPopular: false,
                  onTap: () => Navigator.pop(context),
                ),
                _buildPricingCard(
                  title: 'Pro',
                  description: 'For professional developers shipping apps.',
                  priceMonthlyUSD: 12,
                  priceMonthlyINR: 999,
                  features: [
                    '5,000 logs per session',
                    '2,000 network requests per session',
                    '3 device connections',
                    '7-day data retention',
                    'Export HAR files',
                  ],
                  buttonText: 'Upgrade to Pro',
                  isPopular: true,
                  onTap: () {
                    // TODO: Implement Razorpay integration
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payments coming soon!')),
                    );
                  },
                ),
                _buildPricingCard(
                  title: 'Team',
                  description: 'For small teams collaborating on projects.',
                  priceMonthlyUSD: 49,
                  priceMonthlyINR: 3999,
                  features: [
                    '50,000 logs per session',
                    '20,000 network requests per session',
                    '10 device connections',
                    '30-day data retention',
                    'Shared Team Workspaces',
                    'Real-time Alerts',
                  ],
                  buttonText: 'Upgrade to Team',
                  isPopular: false,
                  onTap: () {
                    // TODO: Implement Razorpay integration
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payments coming soon!')),
                    );
                  },
                ),
                _buildPricingCard(
                  title: 'Enterprise',
                  description: 'Custom solutions for large organizations.',
                  priceMonthlyUSD: 199,
                  priceMonthlyINR: 14999,
                  features: [
                    'Unlimited logs & network requests',
                    '100 device connections',
                    '90-day data retention',
                    'Self-hosted deployment option',
                    'Dedicated Priority Support',
                    'SSO & Advanced Security',
                  ],
                  buttonText: 'Contact Sales',
                  isPopular: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enterprise sales coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCurrencyTab('INR (₹)', true),
          _buildCurrencyTab('USD (\$)', false),
        ],
      ),
    );
  }

  Widget _buildCurrencyTab(String text, bool isINR) {
    final isSelected = _isINR == isINR;
    return GestureDetector(
      onTap: () => setState(() => _isINR = isINR),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Monthly',
          style: TextStyle(
            color: !_isAnnual ? Colors.white : Colors.grey[500],
            fontWeight: !_isAnnual ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: _isAnnual,
          onChanged: (val) => setState(() => _isAnnual = val),
          activeThumbColor: const Color(0xFF38BDF8),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Text(
              'Annually',
              style: TextStyle(
                color: _isAnnual ? Colors.white : Colors.grey[500],
                fontWeight: _isAnnual ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Save 20%',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String description,
    required int priceMonthlyUSD,
    required int priceMonthlyINR,
    required List<String> features,
    required String buttonText,
    required bool isPopular,
    required VoidCallback onTap,
  }) {
    final priceMonthly = _isINR ? priceMonthlyINR : priceMonthlyUSD;
    final currencySymbol = _isINR ? '₹' : '\$';

    // Calculate annual price with 20% discount
    final displayPrice = _isAnnual
        ? (priceMonthly * 0.8).round()
        : priceMonthly;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular
              ? const Color(0xFF38BDF8)
              : Colors.white.withValues(alpha: 0.08),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol$displayPrice',
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '/mo',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            ],
          ),
          if (_isAnnual && displayPrice > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Billed $currencySymbol${displayPrice * 12} yearly',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular
                    ? const Color(0xFF38BDF8)
                    : Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF34D399),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
}
