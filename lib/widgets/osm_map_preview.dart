import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OsmMapPreview extends StatelessWidget {
  const OsmMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 180,
  });

  final double latitude;
  final double longitude;
  final double height;

  static const int zoom = 16;
  static const double tileSize = 256;
  static const String userAgent = 'HRISDignityMobile/1.0';

  static double tileX(double longitude, int zoomLevel) {
    return (longitude + 180) / 360 * math.pow(2, zoomLevel);
  }

  static double tileY(double latitude, int zoomLevel) {
    final double latitudeRad = latitude * math.pi / 180;
    final double mercator = math.log(
      math.tan(latitudeRad) + 1 / math.cos(latitudeRad),
    );
    return (1 - mercator / math.pi) / 2 * math.pow(2, zoomLevel);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        final double centerPixelX = tileX(longitude, zoom);
        final double centerPixelY = tileY(latitude, zoom);
        final double originX = centerPixelX - width / 2;
        final double originY = centerPixelY - height / 2;

        final int minTileX = (originX / tileSize).floor() - 1;
        final int maxTileX = ((originX + width) / tileSize).ceil() + 1;
        final int minTileY = (originY / tileSize).floor() - 1;
        final int maxTileY = ((originY + height) / tileSize).ceil() + 1;
        final int tileCount = math.pow(2, zoom).toInt();

        final List<Widget> tiles = <Widget>[];
        for (int x = minTileX; x <= maxTileX; x++) {
          for (int y = minTileY; y <= maxTileY; y++) {
            final int wrappedX = ((x % tileCount) + tileCount) % tileCount;
            final int safeY = y < 0
                ? 0
                : (y >= tileCount ? tileCount - 1 : y);
            tiles.add(
              Positioned(
                left: x * tileSize - originX,
                top: y * tileSize - originY,
                child: Image.network(
                  'https://tile.openstreetmap.org/$zoom/$wrappedX/$safeY.png',
                  headers: const <String, String>{'User-Agent': userAgent},
                  width: tileSize,
                  height: tileSize,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) =>
                      Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        final double pinX = centerPixelX - originX;
        final double pinY = centerPixelY - originY;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.field,
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: <Widget>[
                  ...tiles,
                  Positioned(
                    left: pinX - 14,
                    top: pinY - 28,
                    child: const IgnorePointer(
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 28,
                        color: AppColors.danger,
                        shadows: <Shadow>[
                          Shadow(offset: Offset(0, 1), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
