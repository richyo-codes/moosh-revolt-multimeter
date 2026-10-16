import 'package:flutter/material.dart';

/// The MooshRevolt logo: the Mooshimeter's translucent pill body with its
/// board and copper jacks (rendered from assets/branding/mooshrevolt_icon.svg).
class MooshRevoltMark extends StatelessWidget {
  const MooshRevoltMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mooshrevolt_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'MooshRevolt logo',
    );
  }
}
