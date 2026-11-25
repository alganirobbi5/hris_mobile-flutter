import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class SelfieFullScreenViewer extends StatelessWidget {
  const SelfieFullScreenViewer({
    super.key,
    required this.title,
    this.subtitle,
    this.localPath,
    this.networkUrl,
    this.headers,
    this.bytes,
  });

  final String title;
  final String? subtitle;
  final String? localPath;
  final String? networkUrl;
  final Map<String, String>? headers;
  final Uint8List? bytes;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? localPath,
    String? networkUrl,
    Map<String, String>? headers,
    Uint8List? bytes,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SelfieFullScreenViewer(
          title: title,
          subtitle: subtitle,
          localPath: localPath,
          networkUrl: networkUrl,
          headers: headers,
          bytes: bytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(child: _buildImage()),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.78),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(bytes!, fit: BoxFit.contain);
    }

    final String? path = localPath;
    if (path != null && path.isNotEmpty) {
      final File file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    }

    final String? url = networkUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        headers: headers,
        fit: BoxFit.contain,
        loadingBuilder: (BuildContext context, Widget child, Object? progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.white70,
            ),
          );
        },
      );
    }

    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 64,
        color: Colors.white70,
      ),
    );
  }
}
