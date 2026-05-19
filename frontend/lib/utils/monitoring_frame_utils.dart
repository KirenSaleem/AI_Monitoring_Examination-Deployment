import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Max longest side for frames sent to AI (preview stays full resolution).
const int kDetectionMaxSide = 416;

/// Resize + compress a captured photo for lightweight upload (runs off UI thread).
Future<String> prepareDetectionFramePath(String capturePath) {
  return compute(_prepareDetectionFrameSync, capturePath);
}

String _prepareDetectionFrameSync(String capturePath) {
  final bytes = File(capturePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode camera frame.');
  }
  final oriented = img.bakeOrientation(decoded);
  final resized = _resizeMaxSide(oriented, kDetectionMaxSide);
  final jpeg = img.encodeJpg(resized, quality: 72);
  final outPath = '$capturePath.det.jpg';
  File(outPath).writeAsBytesSync(jpeg, flush: true);
  return outPath;
}

img.Image _resizeMaxSide(img.Image src, int maxSide) {
  final w = src.width;
  final h = src.height;
  final longest = math.max(w, h);
  if (longest <= maxSide) return src;
  final scale = maxSide / longest;
  return img.copyResize(
    src,
    width: (w * scale).round(),
    height: (h * scale).round(),
    interpolation: img.Interpolation.linear,
  );
}
