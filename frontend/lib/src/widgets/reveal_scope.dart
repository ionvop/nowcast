import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Allocates staggered delays for cards revealed in the same batch.
///
/// A "batch" is one synchronous run of reveal requests — typically every card
/// that becomes visible in the same frame, or every card built during the same
/// page build. The first card in a batch gets no delay, the second waits one
/// [step], and so on, capped at [max]. The counter resets in a microtask once
/// the batch finishes, so a card scrolled into view on its own always animates
/// immediately.
class RevealStagger {
  /// Creates a stagger allocator.
  ///
  /// [step] is the delay added per card and [max] caps the total delay.
  RevealStagger({
    this.step = AppMotion.staggerStep,
    this.max = AppMotion.staggerMax,
  });

  /// The delay added for each additional card in a batch.
  final Duration step;

  /// The largest delay a card can receive.
  final Duration max;

  int _slot = 0;
  bool _batchOpen = false;

  /// Returns the delay for the next card in the current batch.
  Duration nextDelay() {
    if (!_batchOpen) {
      _batchOpen = true;
      // Close the batch once the current synchronous work (a frame's build or
      // a visibility callback run) has finished.
      scheduleMicrotask(() {
        _batchOpen = false;
        _slot = 0;
      });
    }
    final delay = step * _slot;
    _slot++;
    return delay > max ? max : delay;
  }
}

/// Provides the current tab activation and a [RevealStagger] to descendants.
///
/// [FadeSlideIn] replays its entrance animation whenever [activation] changes.
/// The shell increments the counter for a tab each time that tab is selected,
/// which is how animations replay on tab switches even though the screens stay
/// alive inside an [IndexedStack].
class RevealScope extends InheritedWidget {
  /// Creates a reveal scope.
  const RevealScope({
    super.key,
    required this.activation,
    required this.stagger,
    required super.child,
  });

  /// Incremented each time the owning screen becomes the active tab.
  final int activation;

  /// Allocates staggered delays for cards revealed together.
  final RevealStagger stagger;

  /// The nearest enclosing scope, or null when there is none.
  ///
  /// Pushed routes (Settings, Privacy Policy, Post detail, New Post) have no
  /// scope; their cards fall back to a shared default stagger.
  static RevealScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RevealScope>();
  }

  @override
  bool updateShouldNotify(RevealScope oldWidget) {
    return activation != oldWidget.activation || stagger != oldWidget.stagger;
  }
}
