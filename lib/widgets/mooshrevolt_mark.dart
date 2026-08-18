import 'package:flutter/material.dart';

/// The MooshRevolt M-and-lightning brand mark.
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
