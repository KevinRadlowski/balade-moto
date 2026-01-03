import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/vehicle.dart';
import '../../config/api_config.dart';

/// Widget optimisé pour afficher une photo dans la grille
/// Utilise cacheWidth/cacheHeight pour éviter de décoder des images trop grandes
class PhotoGridItem extends StatelessWidget {
  final VehiclePhoto photo;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double size;

  const PhotoGridItem({
    super.key,
    required this.photo,
    this.onTap,
    this.onDelete,
    this.size = 200, // Taille par défaut pour le cache
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ApiConfig.getFileUrl(photo.url),
                fit: BoxFit.cover,
                memCacheWidth: size.toInt(),
                memCacheHeight: size.toInt(),
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
            if (onDelete != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


