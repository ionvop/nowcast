/// Refresh intervals shared by the background heat-alert service and the
/// floating AI bubble.
///
/// Both live in separate isolates, so the constants are kept in this
/// dependency-free library rather than in `heat_alert_service.dart` (which
/// pulls in the background-service and notification plugins).
library;

/// Whether the app was launched with `--dart-define=TEST_INTERVAL=true`.
///
/// When true the periodic refreshers use the fast test intervals instead of
/// the production ones.
const bool kUseTestInterval = bool.fromEnvironment('TEST_INTERVAL');

/// How often the background service re-checks the heat index and refreshes
/// the persistent notification.
const Duration kHeatAlertCheckInterval = Duration(minutes: 15);

/// The faster check interval used when the app is launched with
/// `--dart-define=TEST_INTERVAL=true`, so the persistent notifications refresh
/// quickly for testing.
const Duration kTestHeatAlertCheckInterval = Duration(seconds: 15);

/// How often the floating AI bubble re-reads the current heat index and
/// weather for the user's location.
const Duration kBubbleRefreshInterval = Duration(minutes: 15);

/// The faster bubble refresh interval used when the app is launched with
/// `--dart-define=TEST_INTERVAL=true`.
const Duration kBubbleTestRefreshInterval = Duration(seconds: 15);

/// The heat-alert check interval: the fast test interval when launched with
/// `TEST_INTERVAL=true`, otherwise the production interval.
Duration get heatAlertCheckInterval =>
    kUseTestInterval ? kTestHeatAlertCheckInterval : kHeatAlertCheckInterval;

/// The bubble refresh interval: the fast test interval when launched with
/// `TEST_INTERVAL=true`, otherwise the production interval.
Duration get bubbleRefreshInterval =>
    kUseTestInterval ? kBubbleTestRefreshInterval : kBubbleRefreshInterval;
