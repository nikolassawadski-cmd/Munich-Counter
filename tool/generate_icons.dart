// Generates the app icons in web/: dart run tool/generate_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 1024;

void main() {
  final munich = img.ColorRgb8(0x15, 0x65, 0xC0);
  final heilbronn = img.ColorRgb8(0xC6, 0x28, 0x28);
  final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);

  // Diagonal split: München (blue) top-left, Heilbronn (red) bottom-right.
  final icon = img.Image(width: _size, height: _size);
  img.fill(icon, color: munich);
  img.fillPolygon(icon,
      vertices: [
        img.Point(_size, 0),
        img.Point(_size, _size),
        img.Point(0, _size),
      ],
      color: heilbronn);

  // Two opposing arrows (⇄) kept inside the maskable safe zone.
  const bar = 70;
  const head = 150;
  const left = 260;
  const right = _size - 260;
  void arrow(int y, {required bool pointsRight}) {
    final tip = pointsRight ? right : left;
    final base = pointsRight ? right - head : left + head;
    img.fillRect(icon,
        x1: pointsRight ? left : base,
        y1: y - bar ~/ 2,
        x2: pointsRight ? base : right,
        y2: y + bar ~/ 2,
        color: white);
    img.fillPolygon(icon,
        vertices: [
          img.Point(tip, y),
          img.Point(base, y - head ~/ 1.4),
          img.Point(base, y + head ~/ 1.4),
        ],
        color: white);
  }

  arrow(400, pointsRight: true);
  arrow(624, pointsRight: false);

  void write(String path, int size) {
    final resized = img.copyResize(icon,
        width: size, height: size, interpolation: img.Interpolation.average);
    File(path).writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote $path');
  }

  write('web/icons/Icon-512.png', 512);
  write('web/icons/Icon-192.png', 192);
  write('web/icons/Icon-maskable-512.png', 512);
  write('web/icons/Icon-maskable-192.png', 192);
  write('web/icons/apple-touch-icon.png', 180);
  write('web/favicon.png', 32);
}
