import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/motion.dart';
import 'reveal_scope.dart';

/// The edge a [FadeSlideIn] child travels from while fading in.
enum RevealDirection {
  /// Cards in a vertical list slide in from the right.
  fromRight,

  /// Cards in a horizontal list slide in from the bottom.
  fromBottom,
}

/// Fades and slides [child] into place the first time it scrolls into view.
///
/// The animation plays once per tab activation: it runs on first appearance
/// and again when the user returns to the tab. Cards revealed in the same
/// frame are staggered by the enclosing [RevealScope] so they appear in
/// sequence rather than simultaneously.
///
/// When [enabled] is false, or the platform asks for reduced motion, the child
/// is rendered as-is with no detector and no animation.
class FadeSlideIn extends StatefulWidget {
  /// Creates a fade/slide entrance wrapper.
  const FadeSlideIn({
    super.key,
    this.direction = RevealDirection.fromRight,
    this.duration = AppMotion.revealDuration,
    this.curve = AppMotion.revealCurve,
    this.offset = AppMotion.revealOffset,
    this.enabled = true,
    required this.child,
  });

  /// The edge the child travels from.
  final RevealDirection direction;

  /// How long the fade and slide take, excluding any stagger delay.
  final Duration duration;

  /// The easing applied to the fade and slide.
  final Curve curve;

  /// How far the child travels, in logical pixels.
  final double offset;

  /// When false the child is rendered immediately, without animating.
  final bool enabled;

  /// The widget to reveal.
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

/// Shared stagger used by cards that have no [RevealScope] ancestor, such as
/// those on pushed routes (Settings, Privacy Policy, Post detail, New Post).
final RevealStagger _fallbackStagger = RevealStagger();

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Whether the child currently overlaps the viewport.
  bool _visible = false;

  /// Whether the entrance animation has already run for this activation.
  bool _played = false;

  /// The fraction of the controller timeline spent waiting for the stagger
  /// slot, so the delay needs no separate timer.
  double _startFraction = 0;

  RevealStagger? _stagger;
  int? _activation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RevealScope.maybeOf(context);
    _stagger = scope?.stagger ?? _fallbackStagger;

    final activation = scope?.activation;
    if (_activation != activation) {
      _activation = activation;
      // A new tab activation: allow the entrance to play again.
      _played = false;
      if (_visible) {
        _play();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0;
    if (visible == _visible) return;
    _visible = visible;
    if (visible && !_played) {
      _play();
    }
  }

  /// Starts the entrance animation, folding the stagger delay into the
  /// controller's timeline so the card holds its start state until its turn.
  void _play() {
    _played = true;
    final delay = _stagger?.nextDelay() ?? Duration.zero;
    final total = widget.duration + delay;
    final totalMicros = total.inMicroseconds;
    _startFraction = totalMicros == 0 ? 0 : delay.inMicroseconds / totalMicros;
    _controller.duration = total;
    _controller.forward(from: 0);
  }

  Offset get _beginOffset => switch (widget.direction) {
    RevealDirection.fromRight => Offset(widget.offset, 0),
    RevealDirection.fromBottom => Offset(0, widget.offset),
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || reduceMotion) {
      return widget.child;
    }

    final begin = _beginOffset;
    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: _onVisibilityChanged,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final raw = _controller.value;
          final span = 1 - _startFraction;
          final progress = span <= 0
              ? 1.0
              : ((raw - _startFraction) / span).clamp(0.0, 1.0);
          final eased = widget.curve.transform(progress);
          return Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(begin.dx * (1 - eased), begin.dy * (1 - eased)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
