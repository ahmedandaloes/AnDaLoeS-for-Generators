import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Horizontal photo strip used in the edit-generator form.
/// Displays existing (network) and newly-picked (local) photos with
/// remove actions, plus an "add photo" button while below the cap.
class EditGeneratorPhotosSection extends StatelessWidget {
  const EditGeneratorPhotosSection({
    super.key,
    required this.existingPhotos,
    required this.removedPhotos,
    required this.newPhotos,
    required this.maxPhotos,
    required this.onPickPhoto,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  final List<String> existingPhotos;
  final Set<String> removedPhotos;
  final List<File> newPhotos;
  final int maxPhotos;
  final VoidCallback onPickPhoto;
  final void Function(String url) onRemoveExisting;
  final void Function(int index) onRemoveNew;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keptExisting =
        existingPhotos.where((u) => !removedPhotos.contains(u)).toList();
    final totalPhotos = keptExisting.length + newPhotos.length;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (totalPhotos < maxPhotos)
            _EditPhotoAddButton(onTap: onPickPhoto, cs: cs),
          ...keptExisting.map((url) => _NetworkPhotoThumb(
                url: url,
                onRemove: () => onRemoveExisting(url),
              )),
          ...newPhotos.asMap().entries.map(
                (e) => _LocalPhotoThumb(
                  file: e.value,
                  onRemove: () => onRemoveNew(e.key),
                ),
              ),
        ],
      ),
    );
  }
}

// ── Photo add button ──────────────────────────────────────────────────────────

class _EditPhotoAddButton extends StatelessWidget {
  const _EditPhotoAddButton({required this.onTap, required this.cs});
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        margin: const EdgeInsetsDirectional.only(end: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(l.addPhoto,
                style:
                    TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Network (remote) photo thumbnail ─────────────────────────────────────────

class _NetworkPhotoThumb extends StatelessWidget {
  const _NetworkPhotoThumb({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  void _preview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onRemove();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _preview(context),
          child: Container(
            width: 96,
            height: 96,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15)
                    ]),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 5),
              child: const Icon(Icons.zoom_in_rounded,
                  size: 14, color: Colors.white54),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Local (file) photo thumbnail ──────────────────────────────────────────────

class _LocalPhotoThumb extends StatelessWidget {
  const _LocalPhotoThumb({required this.file, required this.onRemove});
  final File file;
  final VoidCallback onRemove;

  void _preview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onRemove();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _preview(context),
          child: Container(
            width: 96,
            height: 96,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15)
                    ]),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 5),
              child: const Icon(Icons.zoom_in_rounded,
                  size: 14, color: Colors.white54),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
