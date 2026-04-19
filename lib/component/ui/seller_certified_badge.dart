import 'package:flutter/material.dart';

class SellerCertifiedMiniBadge extends StatelessWidget {
  const SellerCertifiedMiniBadge({super.key, this.label = 'Vendeur certifie'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SellerCertifiedBadge.mini(label: label);
  }
}

class SellerCertifiedBadge extends StatelessWidget {
  const SellerCertifiedBadge({
    super.key,
    this.label = 'Vendeur certifie',
    this.compact = false,
  });

  const SellerCertifiedBadge.mini({super.key, this.label = 'Vendeur certifie'})
    : compact = true;

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF101314) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF172027);
    final outerRadius = compact ? 15.0 : 24.0;
    final innerRadius = compact ? 14.0 : 23.0;
    final iconSize = compact ? 11.0 : 18.0;
    final iconBoxSize = compact ? 22.0 : 36.0;
    final borderThickness = compact ? 1.0 : 1.4;
    final badgePadding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 9);
    final titleStyle = TextStyle(
      color: titleColor,
      fontWeight: FontWeight.w900,
      letterSpacing: compact ? 0.0 : 0.15,
      height: 1,
      fontSize: compact ? 9.5 : null,
    );
    final accentSpacing = compact ? 6.0 : 12.0;
    final accentWidth = compact ? 2.0 : 4.0;
    final accentHeight = compact ? 16.0 : 30.0;
    final iconGap = compact ? 6.0 : 10.0;
    final shadowBlur = compact ? 6.0 : 18.0;
    final shadowOffset = compact ? const Offset(0, 3) : const Offset(0, 10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E9F53).withOpacity(0.14),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerRadius),
        child: Container(
          padding: EdgeInsets.all(borderThickness),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, Color(0xFF2E9F53), Color(0xFFD94747)],
            ),
          ),
          child: Container(
            padding: badgePadding,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFEAF6EE)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF2E9F53).withOpacity(0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: iconSize,
                    color: Color(0xFF1E7A34),
                  ),
                ),
                SizedBox(width: iconGap),
                Text(label, style: titleStyle),
                SizedBox(width: accentSpacing),
                Container(
                  width: accentWidth,
                  height: accentHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFF2E9F53),
                        Color(0xFFD94747),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
