import 'package:flutter/material.dart';

import 'chain_style.dart';

class ChainMarker extends StatelessWidget {
  final String? chain;

  const ChainMarker({super.key, required this.chain});

  @override
  Widget build(BuildContext context) {
    final style = ChainStyle.forChain(chain);

    // Contraste: si el fondo es muy claro (amarillo Lidl), letra negra; si no, blanca.
    final brightness = ThemeData.estimateBrightnessForColor(style.color);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        style.initial,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
