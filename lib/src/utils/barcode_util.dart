import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Utilities for encoding Code 128 barcodes and rendering them to widgets and PNG images
class BarcodeUtil {
  /// Generate patterns for Code 128 B
  static const Map<String, String> _code128Table = {
    ' ': '11011001100', '!': '11001101100', '"': '11001100110', '#': '10010011000',
    '\$': '10010001100', '%': '10001001100', '&': '10011001000', '\'': '10011000100',
    '(': '10001100100', ')': '11001001000', '*': '11001000100', '+': '11000100100',
    ',': '10110011100', '-': '10011011100', '.': '10011001110', '/': '10111001100',
    '0': '10011101100', '1': '10011100110', '2': '11001110010', '3': '11001011100',
    '4': '11001001110', '5': '11011100100', '6': '11001110100', '7': '11101101110',
    '8': '11101001100', '9': '11100101100', ':': '11100100110', ';': '11101100100',
    '<': '11100110100', '=': '11100110010', '>': '11011011000', '?': '11011000110',
    '@': '11000110110', 'A': '10100011000', 'B': '10001011000', 'C': '10001000110',
    'D': '10110001000', 'E': '10001101000', 'F': '10001100010', 'G': '11010001000',
    'H': '11000101000', 'I': '11000100010', 'J': '10110111000', 'K': '10110001110',
    'L': '10001101110', 'M': '10111011000', 'N': '10111000110', 'O': '10001110110',
    'P': '11101110110', 'Q': '11010001110', 'R': '11000101110', 'S': '11011101000',
    'T': '11011100010', 'U': '11011101110', 'V': '11101011000', 'W': '11101000110',
    'X': '11100010110', 'Y': '11101101000', 'Z': '11101100010', '[': '11100011010',
    '\\': '11101111010', ']': '11001000010', '^': '11110001010', '_': '10100110000',
    '`': '10100001100', 'a': '10010110000', 'b': '10010000110', 'c': '10000101100',
    'd': '10000100110', 'e': '10110010000', 'f': '10110000100', 'g': '10011010000',
    'h': '10011000010', 'i': '10000110100', 'j': '10000110010', 'k': '11000010010',
    'l': '11001010000', 'm': '11110111010', 'n': '11000010100', 'o': '10001111010',
    'p': '10100111100', 'q': '10010111100', 'r': '10010011110', 's': '10111100100',
    't': '10011110100', 'u': '10011110010', 'v': '11110100100', 'w': '11110010100',
    'x': '11110010010', 'y': '11011011110', 'z': '11011110110', '{': '11110110110',
    '|': '10101111000', '}': '10100011110', '~': '10001011110',
  };

  static const String _startB = '11010010000';
  static const String _stop = '1100011101011';

  /// Encode a text string into binary bar pattern ('1' for bar, '0' for space)
  static String encodeToBinary(String text) {
    if (text.isEmpty) text = 'UNKNOWN';
    final buffer = StringBuffer();
    buffer.write('0000000000'); // Quiet zone
    buffer.write(_startB);

    int checksum = 104; // Start B code value
    int weight = 1;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final pattern = _code128Table[char] ?? _code128Table['-']!;
      buffer.write(pattern);

      final charValue = _getCharValue(char);
      checksum += charValue * weight;
      weight++;
    }

    // Checksum char pattern
    final checksumIndex = checksum % 103;
    final checksumPattern = _getPatternByIndex(checksumIndex);
    buffer.write(checksumPattern);

    buffer.write(_stop);
    buffer.write('0000000000'); // Quiet zone
    return buffer.toString();
  }

  static int _getCharValue(String char) {
    final ascii = char.codeUnitAt(0);
    if (ascii >= 32 && ascii <= 126) {
      return ascii - 32;
    }
    return 13; // default dash
  }

  static String _getPatternByIndex(int index) {
    if (index >= 0 && index < _code128Table.length) {
      return _code128Table.values.elementAt(index);
    }
    return _code128Table['-']!;
  }

  /// Render barcode image to PNG Uint8List bytes without any external file plugins
  static Future<Uint8List> generateBarcodeImageBytes({
    required String data,
    required String title,
    String? subtitle,
    double width = 450,
    double height = 220,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final paintBg = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, height), const Radius.circular(12)),
      paintBg,
    );

    // Title / Component Name
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xff19335A),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 30);
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, 16));

    // Subtitle / Box if provided
    double barcodeTop = 44;
    if (subtitle != null && subtitle.isNotEmpty) {
      final subPainter = TextPainter(
        text: TextSpan(
          text: subtitle,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 30);
      subPainter.paint(canvas, Offset((width - subPainter.width) / 2, 40));
      barcodeTop = 60;
    }

    // Draw Barcode lines
    final binaryPattern = encodeToBinary(data);
    final barcodeHeight = height - barcodeTop - 45;
    final barWidth = (width - 40) / binaryPattern.length;
    final paintBar = Paint()..color = Colors.black;

    for (int i = 0; i < binaryPattern.length; i++) {
      if (binaryPattern[i] == '1') {
        canvas.drawRect(
          Rect.fromLTWH(20 + (i * barWidth), barcodeTop, barWidth + 0.4, barcodeHeight),
          paintBar,
        );
      }
    }

    // SKU Code Text below barcode
    final textPainter = TextPainter(
      text: TextSpan(
        text: '* $data *',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 30);
    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, height - 32));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Download / Share Barcode Image using cross-platform in-memory XFile
  static Future<void> downloadOrShareBarcode({
    required BuildContext context,
    required String skuId,
    required String compName,
    String? boxNo,
  }) async {
    try {
      final bytes = await generateBarcodeImageBytes(
        data: skuId,
        title: compName,
        subtitle: boxNo != null && boxNo.isNotEmpty ? 'Box: $boxNo' : null,
      );

      final sanitizedSku = skuId.replaceAll(RegExp(r'[^\w\-]'), '_');
      final fileName = 'barcode_$sanitizedSku.png';

      // Use in-memory XFile.fromData (cross-platform, zero path_provider or dart:io dependency)
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      );

      await Share.shareXFiles(
        [xFile],
        text: 'Barcode for $compName ($skuId)',
        subject: 'Barcode: $skuId',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode generated for $skuId'),
            backgroundColor: const Color(0xff19335A),
          ),
        );
      }
    } catch (_) {
      // Fallback: Copy SKU and show instant confirmation without crashing
      await Clipboard.setData(ClipboardData(text: skuId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode SKU ($skuId) copied to clipboard!'),
            backgroundColor: const Color(0xff19335A),
          ),
        );
      }
    }
  }
}

/// Custom widget that paints a Barcode directly on Canvas
class BarcodeWidget extends StatelessWidget {
  final String data;
  final double height;
  final double width;
  final Color color;

  const BarcodeWidget({
    super.key,
    required this.data,
    this.height = 70,
    this.width = double.infinity,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final pattern = BarcodeUtil.encodeToBinary(data);
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _BarcodePainter(pattern: pattern, color: color),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String pattern;
  final Color color;

  _BarcodePainter({required this.pattern, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.isEmpty) return;
    final paint = Paint()..color = color;
    final barWidth = size.width / pattern.length;

    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i] == '1') {
        canvas.drawRect(
          Rect.fromLTWH(i * barWidth, 0, barWidth + 0.3, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.color != color;
}
