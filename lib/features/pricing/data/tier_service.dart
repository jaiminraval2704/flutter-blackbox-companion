/// Defines feature limits for each subscription tier.
///
/// Used by [FirebaseService] and the dashboard to enforce usage caps
/// and show upgrade prompts when limits are reached.
class TierService {
  static final TierService _instance = TierService._();
  static TierService get instance => _instance;

  TierService._();

  /// Returns the [TierConfig] for the given tier name.
  TierConfig configFor(String tier) {
    switch (tier) {
      case 'pro':
        return TierConfig.pro;
      case 'team':
        return TierConfig.team;
      case 'enterprise':
        return TierConfig.enterprise;
      default:
        return TierConfig.free;
    }
  }
}

/// Immutable configuration defining the limits for a subscription tier.
class TierConfig {
  const TierConfig({
    required this.name,
    required this.maxLogsPerSession,
    required this.maxNetworkPerSession,
    required this.maxCrashes,
    required this.maxSessionHistory,
    required this.retentionHours,
    required this.maxDevices,
    required this.canExport,
    required this.canShareSessions,
    required this.canUseTeamWorkspace,
    required this.canUseAlerts,
    required this.hasPrioritySupport,
  });

  final String name;
  final int maxLogsPerSession;
  final int maxNetworkPerSession;
  final int maxCrashes;
  final int maxSessionHistory;
  final int retentionHours;
  final int maxDevices;
  final bool canExport;
  final bool canShareSessions;
  final bool canUseTeamWorkspace;
  final bool canUseAlerts;
  final bool hasPrioritySupport;

  /// Whether the given count has reached the max for logs.
  bool isLogsAtCapacity(int count) => count >= maxLogsPerSession;

  /// Whether the given count has reached the max for network entries.
  bool isNetworkAtCapacity(int count) => count >= maxNetworkPerSession;

  // ── Tier presets ────────────────────────────────────────────────────

  static const free = TierConfig(
    name: 'Free',
    maxLogsPerSession: 100,
    maxNetworkPerSession: 50,
    maxCrashes: 10,
    maxSessionHistory: 5,
    retentionHours: 24,
    maxDevices: 1,
    canExport: false,
    canShareSessions: false,
    canUseTeamWorkspace: false,
    canUseAlerts: false,
    hasPrioritySupport: false,
  );

  static const pro = TierConfig(
    name: 'Pro',
    maxLogsPerSession: 5000,
    maxNetworkPerSession: 2000,
    maxCrashes: 500,
    maxSessionHistory: 20,
    retentionHours: 24 * 7, // 7 days
    maxDevices: 3,
    canExport: true,
    canShareSessions: false,
    canUseTeamWorkspace: false,
    canUseAlerts: false,
    hasPrioritySupport: false,
  );

  static const team = TierConfig(
    name: 'Team',
    maxLogsPerSession: 50000,
    maxNetworkPerSession: 20000,
    maxCrashes: 5000,
    maxSessionHistory: 100,
    retentionHours: 24 * 30, // 30 days
    maxDevices: 10,
    canExport: true,
    canShareSessions: true,
    canUseTeamWorkspace: true,
    canUseAlerts: true,
    hasPrioritySupport: false,
  );

  static const enterprise = TierConfig(
    name: 'Enterprise',
    maxLogsPerSession: 500000,
    maxNetworkPerSession: 200000,
    maxCrashes: 50000,
    maxSessionHistory: 1000,
    retentionHours: 24 * 90, // 90 days
    maxDevices: 100,
    canExport: true,
    canShareSessions: true,
    canUseTeamWorkspace: true,
    canUseAlerts: true,
    hasPrioritySupport: true,
  );
}
