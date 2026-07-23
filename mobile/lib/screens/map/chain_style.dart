import 'package:flutter/material.dart';

class ChainStyle {
  final Color color;
  final String initial;

  const ChainStyle(this.color, this.initial);

  static const _fallback = ChainStyle(Colors.grey, '?');

  static const _map = <String, ChainStyle>{
    'Mercadona': ChainStyle(Color(0xFF00A551), 'M'),
    'Carrefour': ChainStyle(Color(0xFF004E9F), 'C'),
    'Lidl':      ChainStyle(Color(0xFFFFF000), 'L'),
    'Aldi':      ChainStyle(Color(0xFF00549A), 'A'),
    'Consum':    ChainStyle(Color(0xFFE30613), 'C'),
    'DIA':       ChainStyle(Color(0xFFE30613), 'D'),
    'Alcampo':   ChainStyle(Color(0xFFE30613), 'A'),
  };

  static ChainStyle forChain(String? chain) {
    if (chain == null) return _fallback;
    return _map[chain] ?? _fallback;
  }
}