import 'package:flutter/material.dart';

/// Colore di una sestiglia dal suo nome (Bianchi, Grigi, Neri, Rossi, Fulvi...).
/// Per i nomi non riconosciuti si sceglie un colore stabile dalla tavolozza.
Color coloreSestiglia(String nome) {
  final n = nome.toLowerCase();
  const note = <String, Color>{
    'bianc': Color(0xFFE9ECE4),
    'grig': Color(0xFF8B97A3),
    'ner': Color(0xFF2B2F2D),
    'ross': Color(0xFFC4452D),
    'fulv': Color(0xFF8A2B3C), // rosso vinaccio
    'brun': Color(0xFF7A4B2A),
    'pezzat': Color(0xFFB59B7A),
    'tigrat': Color(0xFFD9A93B),
    'azzurr': Color(0xFF4A93D0),
    'blu': Color(0xFF2F6FA3),
    'verd': Color(0xFF3F8F5A),
    'giall': Color(0xFFF2B418),
    'arancio': Color(0xFFE2792D),
    'viola': Color(0xFF7B5EA7),
    'rosa': Color(0xFFD9809B),
  };
  for (final e in note.entries) {
    if (n.contains(e.key)) return e.value;
  }
  const tavolozza = [
    Color(0xFF3F8F5A),
    Color(0xFF2F6FA3),
    Color(0xFFD08A2C),
    Color(0xFF7B5EA7),
    Color(0xFFC4452D),
    Color(0xFF2E8C8C),
  ];
  return tavolozza[n.codeUnits.fold<int>(0, (a, b) => a + b) % tavolozza.length];
}

/// Testo leggibile sopra [sfondo].
Color testoSu(Color sfondo) =>
    ThemeData.estimateBrightnessForColor(sfondo) == Brightness.dark ? Colors.white : const Color(0xFF17261E);
