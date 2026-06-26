import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../providers/cart_provider.dart';

/// Reusable cart icon button with real-time badge count and bounce animation.
///
/// Use this widget across all screens (home, product details, etc.) to ensure
/// the cart badge count is always synchronized with Firestore.
///
/// The icon animates with a bounce when the cart count increases.
class CartIconButton extends ConsumerStatefulWidget {
  final double iconSize;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const CartIconButton({
    super.key,
    this.iconSize = 33,
    this.badgeColor,
    this.badgeTextColor,
  });

  @override
  ConsumerState<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends ConsumerState<CartIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
        ]).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(cartItemCountProvider);

    // Trigger bounce animation when count increases
    if (count > _previousCount && _previousCount >= 0) {
      _animController.forward(from: 0.0);
    }
    _previousCount = count;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.shoppingCart),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: count > 0
            ? Badge(
                backgroundColor: widget.badgeColor ?? Colors.red,
                label: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: widget.badgeTextColor ?? Colors.white,
                  ),
                ),
                child: SvgPicture.asset(
                  'assets/icons/cart_icon.svg',
                  width: widget.iconSize,
                  height: widget.iconSize,
                ),
              )
            : SvgPicture.asset(
                'assets/icons/cart_icon.svg',
                width: widget.iconSize,
                height: widget.iconSize,
              ),
      ),
    );
  }
}
