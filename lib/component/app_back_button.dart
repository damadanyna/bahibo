import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final EdgeInsetsGeometry padding;

  const AppBackButton({
    super.key,
    this.onTap,
    this.size = 46,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: padding,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
