import 'package:flutter/material.dart';

class AssetIcon extends StatelessWidget {
  const AssetIcon(
    this.asset, {
    super.key,
    this.size = 28,
    this.selected = false,
  });

  final String asset;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 0 : size * 0.04),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
