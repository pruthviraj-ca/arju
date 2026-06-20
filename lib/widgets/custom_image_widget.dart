/// custom_image_widget.dart
///
/// Flexible image widget that automatically selects the correct rendering
/// strategy based on the image URL/path type: SVG asset, local file,
/// network URL (with caching), or bundled PNG asset.
///
/// Supports tap callbacks, border radius, margin, border decoration,
/// and custom error/placeholder widgets.

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_export.dart';

// ─── Image Type Detection ──────────────────────────────────────────────────────

/// Extension on [String] to infer the [ImageType] from the path or URL.
extension ImageTypeExtension on String {
  ImageType get imageType {
    if (startsWith('http') || startsWith('https')) return ImageType.network;
    if (endsWith('.svg')) return ImageType.svg;
    if (startsWith('file://')) return ImageType.file;
    return ImageType.png;
  }
}

/// Describes how an image source should be rendered.
enum ImageType { svg, png, network, file, unknown }

// ─── Widget ───────────────────────────────────────────────────────────────────

// ignore_for_file: must_be_immutable
/// A universal image widget that handles SVG, file, network, and asset images.
///
/// Pass any [imageUrl] (URL, asset path, or file path) and the widget
/// automatically uses the correct loader. Network images are cached via
/// [CachedNetworkImage].
class CustomImageWidget extends StatelessWidget {
  const CustomImageWidget({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.color,
    this.fit,
    this.alignment,
    this.onTap,
    this.radius,
    this.margin,
    this.border,
    this.placeHolder = 'assets/images/no-image.jpg',
    this.errorWidget,
    this.semanticLabel,
  });

  /// Image source: a network URL, asset path, or local file path.
  final String? imageUrl;

  /// Desired render height in logical pixels.
  final double? height;

  /// Desired render width in logical pixels.
  final double? width;

  /// Optional color tint applied to the image.
  final Color? color;

  /// How the image should be inscribed into the box. Defaults to [BoxFit.cover].
  final BoxFit? fit;

  /// Alignment of the image within its parent [Align] widget, if provided.
  final Alignment? alignment;

  /// Optional tap callback, forwarded to [InkWell].
  final VoidCallback? onTap;

  /// Optional border radius to clip the image.
  final BorderRadius? radius;

  /// Optional outer margin applied around the image.
  final EdgeInsetsGeometry? margin;

  /// Optional border decoration drawn around the image.
  final BoxBorder? border;

  /// Fallback asset path shown while a network image is loading.
  final String placeHolder;

  /// Custom widget to display if the image fails to load.
  /// Falls back to [placeHolder] if not provided.
  final Widget? errorWidget;

  /// Accessibility label for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final imageContent = _buildWithMarginAndTap();
    return alignment != null
        ? Align(alignment: alignment!, child: imageContent)
        : imageContent;
  }

  /// Wraps the image with optional margin and tap gesture.
  Widget _buildWithMarginAndTap() {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: InkWell(onTap: onTap, child: _buildWithBorderRadius()),
    );
  }

  /// Applies optional border-radius clipping to the image.
  Widget _buildWithBorderRadius() {
    if (radius != null) {
      return ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: _buildWithBorder(),
      );
    }
    return _buildWithBorder();
  }

  /// Wraps the image in a [Container] with an optional [border].
  Widget _buildWithBorder() {
    if (border != null) {
      return Container(
        decoration: BoxDecoration(border: border, borderRadius: radius),
        child: _buildImageView(),
      );
    }
    return _buildImageView();
  }

  /// Selects the correct image renderer based on [imageUrl.imageType].
  Widget _buildImageView() {
    if (imageUrl == null) return const SizedBox.shrink();

    switch (imageUrl!.imageType) {
      case ImageType.svg:
        return SizedBox(
          height: height,
          width: width,
          child: SvgPicture.asset(
            imageUrl!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.contain,
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
            semanticsLabel: semanticLabel,
          ),
        );

      case ImageType.file:
        return Image.file(
          File(imageUrl!),
          height: height,
          width: width,
          fit: fit ?? BoxFit.cover,
          color: color,
          semanticLabel: semanticLabel,
        );

      case ImageType.network:
        return CachedNetworkImage(
          height: height,
          width: width,
          fit: fit,
          imageUrl: imageUrl!,
          color: color,
          placeholder: (context, url) => SizedBox(
            height: 30,
            width: 30,
            child: LinearProgressIndicator(
              color: Colors.grey.shade200,
              backgroundColor: Colors.grey.shade100,
            ),
          ),
          errorWidget: (context, url, error) =>
              errorWidget ??
              Image.asset(
                placeHolder,
                height: height,
                width: width,
                fit: fit ?? BoxFit.cover,
                semanticLabel: semanticLabel,
              ),
        );

      case ImageType.png:
      default:
        return Image.asset(
          imageUrl!,
          height: height,
          width: width,
          fit: fit ?? BoxFit.cover,
          color: color,
          semanticLabel: semanticLabel,
        );
    }
  }
}
