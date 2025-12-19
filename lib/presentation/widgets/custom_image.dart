import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CustomImage extends StatelessWidget {
  const CustomImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      cacheKey: imageUrl,
      useOldImageOnUrlChange: true,

      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => const Center(child: LoadingIndicator()),

      errorWidget: (context, url, error) =>
          Image.asset("assets/images/image.png", fit: BoxFit.cover),
    );
  }
}

CachedNetworkImageProvider customImageProvider(String imageUrl) {
  return CachedNetworkImageProvider(imageUrl, cacheKey: imageUrl);
}
