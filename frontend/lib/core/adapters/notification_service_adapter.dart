/// Abstract interface for the native high-heat notification service.
///
/// On **web** the service is a no-op: the "high heat" condition may still be
/// shown as an in-app alert while the page is open (handled by the Home
/// screen), but no background notification is produced.
abstract class NotificationServiceAdapter {
  /// Whether background notifications are supported on this platform.
  bool get isSupported;

  /// Whether the foreground monitoring service is currently enabled.
  bool get isEnabled;

  /// Initializes the service (no-op on web).
  Future<void> init();

  /// Starts monitoring. Native-only; web returns without doing anything.
  Future<void> start();

  /// Stops monitoring. Native-only; web returns without doing anything.
  Future<void> stop();

  /// Toggles monitoring on/off. Returns the new state.
  Future<bool> toggle();

  /// Called by the Home screen to evaluate whether to show an in-app high-heat
  /// alert. On web this is the only mechanism; on native it is supplementary.
  Future<void> evaluateCurrent({required double? heatIndex});
}

/// Web no-op implementation (also a safe default for unsupported platforms).
class NoopNotificationServiceAdapter implements NotificationServiceAdapter {
  const NoopNotificationServiceAdapter();

  @override
  bool get isSupported => false;

  @override
  bool get isEnabled => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> toggle() async => false;

  @override
  Future<void> evaluateCurrent({double? heatIndex}) async {}
}

/// Returns the appropriate notification service for the current platform.
/// On web (and any unsupported platform for now) this is a no-op. The native
/// implementation is added in Phase 8.
NotificationServiceAdapter createNotificationServiceAdapter() {
  return const NoopNotificationServiceAdapter();
}
