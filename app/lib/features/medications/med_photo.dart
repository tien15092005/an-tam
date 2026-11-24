import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'medications_api.dart';

/// A medication photo loaded through the signed-in API client (caregiver side).
class RemoteMedPhoto extends ConsumerWidget {
  const RemoteMedPhoto({super.key, required this.url, this.size = 64});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(medicationImageProvider(url));
    return _Frame(
      size: size,
      child: bytes.when(
        data: (b) => Image.memory(b, fit: BoxFit.cover, width: size, height: size),
        loading: () => const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, _) => Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    );
  }
}

/// A photo already saved on the elder's phone (works offline).
class LocalMedPhoto extends StatelessWidget {
  const LocalMedPhoto({super.key, required this.path, this.size = 96});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) => _Frame(
        size: size,
        child: Image.file(File(path), fit: BoxFit.cover, width: size, height: size,
            errorBuilder: (_, _, _) => Icon(Icons.medication, color: AppColors.primary)),
      );
}

/// Placeholder when a medication has no photo yet.
class NoMedPhoto extends StatelessWidget {
  const NoMedPhoto({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) =>
      _Frame(size: size, child: Icon(Icons.medication, color: AppColors.primary, size: size * 0.5));
}

class _Frame extends StatelessWidget {
  const _Frame({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(width: size, height: size, color: AppColors.primarySoft, child: child),
      );
}
