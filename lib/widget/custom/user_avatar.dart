import 'package:flutter/material.dart';

/// A reusable avatar widget used across friend, profile, and achievement screens.
///
/// Centralises the default-avatar path, null/empty checks, error fallback,
/// and the circular (or rounded-rect) clipping so every call-site is a
/// single, clean widget instead of 15–20 lines of nested containers.
class UserAvatar extends StatelessWidget {
  /// The single source-of-truth for the fallback avatar asset.
  static const String defaultPath = 'assets/avatar/default_avatar.jpg';

  /// Raw path coming from the model – may be null or blank.
  final String? avatarPath;

  /// Diameter of the avatar image (excluding the border).
  final double size;

  /// Border colour drawn around the avatar.
  /// Ignored when [borderWidth] is 0.
  final Color borderColor;

  /// Thickness of the outer border ring. Set to 0 to hide it.
  final double borderWidth;

  /// Padding between the border ring and the image.
  /// Only relevant when [borderWidth] > 0.
  final double borderPadding;

  /// If non-null the avatar is clipped to a rounded rectangle instead of a
  /// circle.  Pass `BorderRadius.circular(12)` for the avatar-picker style.
  final BorderRadius? borderRadius;

  /// Colour used for the error-state icon. Falls back to [borderColor].
  final Color? fallbackIconColor;

  const UserAvatar({
    super.key,
    this.avatarPath,
    this.size = 48,
    this.borderColor = const Color(0x803B82F6),
    this.borderWidth = 0,
    this.borderPadding = 2,
    this.borderRadius,
    this.fallbackIconColor,
  });

  /// Resolve null / blank paths to the built-in default.
  String get _resolvedPath {
    final p = avatarPath;
    if (p == null || p.trim().isEmpty) return defaultPath;
    return p.trim();
  }

  /// Convenience helper used by screens that need the raw resolved string
  /// without instantiating the widget (e.g. [AvatarPickerCard] label logic).
  static String resolve(String? path) {
    if (path == null || path.trim().isEmpty) return defaultPath;
    return path.trim();
  }

  /// Pre-warm the image cache for a list of avatar paths.
  /// Call this once (e.g. after data loads) so images appear instantly
  /// when the widgets build.
  static Future<void> precacheAvatars(
      BuildContext context,
      Iterable<String?> paths, {
        double decodeSize = 128,
      }) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (decodeSize * pixelRatio).toInt();

    for (final raw in paths) {
      final resolved = resolve(raw);
      try {
        await precacheImage(
          ResizeImage(
            AssetImage(resolved),
            width: cacheSize,
            height: cacheSize,
          ),
          context,
        );
      } catch (_) {
        // Asset missing or broken – silently skip.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = fallbackIconColor ?? borderColor;
    final isCircle = borderRadius == null;

    // Decode at display-size × devicePixelRatio for crisp rendering
    // on high-DPI screens without paying the cost of decoding a
    // full-resolution source image.
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheExtent = (size * pixelRatio).toInt();

    Widget image = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _resolvedPath,
        fit: BoxFit.cover,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        errorBuilder: (_, __, ___) => Container(
          color: iconColor.withOpacity(0.15),
          alignment: Alignment.center,
          child: Icon(Icons.person, color: iconColor, size: size * 0.5),
        ),
      ),
    );

    // Clip to shape
    if (isCircle) {
      image = ClipOval(child: image);
    } else {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    // Wrap with a border ring when requested
    if (borderWidth > 0) {
      image = Container(
        padding: EdgeInsets.all(borderPadding),
        decoration: BoxDecoration(
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : borderRadius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: image,
      );
    }

    return image;
  }
}