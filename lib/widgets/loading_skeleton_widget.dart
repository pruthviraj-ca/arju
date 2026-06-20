/// loading_skeleton_widget.dart
///
/// Provides animated shimmer-effect placeholder widgets shown while
/// content is loading from Firestore. Includes a base [LoadingSkeletonWidget]
/// for arbitrary-sized blocks and a [LeadCardSkeletonWidget] that matches
/// the layout of a lead list card.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Base Skeleton ─────────────────────────────────────────────────────────────

/// A single rectangular block with a left-to-right shimmer animation.
///
/// Use multiple instances to build composite skeleton layouts.
///
/// [width]        - Width of the skeleton block in logical pixels.
/// [height]       - Height of the skeleton block in logical pixels.
/// [borderRadius] - Corner radius of the block. Defaults to 8.
class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    // Repeat the shimmer sweep continuously.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: [
              AppTheme.borderColor,
              AppTheme.borderColor.withAlpha(102),
              AppTheme.borderColor,
            ],
            stops: [
              (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
              _shimmerAnimation.value.clamp(0.0, 1.0),
              (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

// ─── Lead Card Skeleton ────────────────────────────────────────────────────────

/// A composite skeleton that matches the visual layout of a [LeadCardWidget].
///
/// Show a list of these while the lead stream is loading to avoid
/// a blank screen flash.
class LeadCardSkeletonWidget extends StatelessWidget {
  const LeadCardSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoadingSkeletonWidget(width: 160, height: 16, borderRadius: 4),
              const Spacer(),
              const LoadingSkeletonWidget(width: 70, height: 22, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 10),
          const LoadingSkeletonWidget(width: 120, height: 13, borderRadius: 4),
          const SizedBox(height: 6),
          const LoadingSkeletonWidget(width: 200, height: 13, borderRadius: 4),
          const SizedBox(height: 12),
          Row(
            children: const [
              LoadingSkeletonWidget(width: 80, height: 13, borderRadius: 4),
              SizedBox(width: 16),
              LoadingSkeletonWidget(width: 100, height: 13, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Site Visit Card Skeleton ──────────────────────────────────────────────────

class SiteVisitCardSkeletonWidget extends StatelessWidget {
  const SiteVisitCardSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              LoadingSkeletonWidget(width: 80, height: 20, borderRadius: 8),
              LoadingSkeletonWidget(width: 28, height: 28, borderRadius: 14),
            ],
          ),
          const SizedBox(height: 12),
          const LoadingSkeletonWidget(width: 150, height: 16, borderRadius: 4),
          const SizedBox(height: 6),
          Row(
            children: const [
              LoadingSkeletonWidget(width: 14, height: 14, borderRadius: 2),
              SizedBox(width: 6),
              LoadingSkeletonWidget(width: 120, height: 13, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              LoadingSkeletonWidget(width: 100, height: 13, borderRadius: 4),
              LoadingSkeletonWidget(width: 120, height: 28, borderRadius: 20),
            ],
          ),
        ],
      ),
    );
  }
}
