import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Picks a profile image from gallery with permissions + compression (for Flutter flows).
class ProfileImagePicker {
  ProfileImagePicker._();

  static final ImagePicker _picker = ImagePicker();

  static Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      if (status.isGranted) return true;

      // Android 12 and below fallback
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  /// Returns compressed JPEG bytes, or null if cancelled.
  static Future<Uint8List?> pickFromGallery({
    int maxSide = 1024,
    int jpegQuality = 82,
  }) async {
    final allowed = await _ensureGalleryPermission();
    if (!allowed) {
      throw StateError('Gallery permission is required to choose a photo.');
    }

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      requestFullMetadata: true,
    );
    if (picked == null) return null;

    final raw = await picked.readAsBytes();
    return compute(
      _compressBytes,
      _CompressArgs(raw, maxSide, jpegQuality),
    );
  }

  static Uint8List _compressBytes(_CompressArgs args) {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) {
      throw StateError('Could not read the selected image. Try another photo.');
    }
    final oriented = img.bakeOrientation(decoded);
    final resized = _resizeMaxSide(oriented, args.maxSide);
    return Uint8List.fromList(img.encodeJpg(resized, quality: args.jpegQuality));
  }

  static img.Image _resizeMaxSide(img.Image src, int maxSide) {
    final longest = src.width > src.height ? src.width : src.height;
    if (longest <= maxSide) return src;
    final scale = maxSide / longest;
    return img.copyResize(
      src,
      width: (src.width * scale).round(),
      height: (src.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }
}

class _CompressArgs {
  final Uint8List bytes;
  final int maxSide;
  final int jpegQuality;

  _CompressArgs(this.bytes, this.maxSide, this.jpegQuality);
}

/// Circular avatar preview for a picked profile image.
class ProfileImagePreview extends StatelessWidget {
  final Uint8List? imageBytes;
  final double size;
  final VoidCallback? onTap;
  final String placeholderLabel;

  const ProfileImagePreview({
    super.key,
    required this.imageBytes,
    this.size = 112,
    this.onTap,
    this.placeholderLabel = 'Tap to add photo',
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null && imageBytes!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.indigo.shade200, width: 2),
              image: hasImage
                  ? DecorationImage(
                      image: MemoryImage(imageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasImage
                ? null
                : Icon(Icons.person_rounded, size: size * 0.45, color: Colors.grey.shade500),
          ),
          if (!hasImage) ...[
            const SizedBox(height: 8),
            Text(
              placeholderLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
