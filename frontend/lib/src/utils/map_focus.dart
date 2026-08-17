import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Global controller for focusing the Map tab on a location, e.g. when a
/// community post's tagged location is tapped.
///
/// The community screens call [focusOn] to request that the app switch to the
/// Map tab and center the camera on a coordinate. [AppShell] listens for the
/// tab change and [MapScreen] listens for the pending center.
class MapFocusController extends ChangeNotifier {
  /// Index of the Map destination in the bottom navigation bar.
  static const int mapTabIndex = 2;

  LatLng? _pendingCenter;
  int _selectedTab = 0;

  /// The currently selected bottom-nav tab index.
  int get selectedTab => _selectedTab;

  /// Requests the app to switch to the Map tab and center on [center].
  void focusOn(LatLng center) {
    _pendingCenter = center;
    _selectedTab = mapTabIndex;
    notifyListeners();
  }

  /// Returns and clears the pending center, or null when none is pending.
  LatLng? takePendingCenter() {
    final center = _pendingCenter;
    _pendingCenter = null;
    return center;
  }
}

/// Global singleton used across the app.
final MapFocusController mapFocus = MapFocusController();
