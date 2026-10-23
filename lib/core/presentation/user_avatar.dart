import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/domain/ports.dart';
import '../../features/notes/presentation/controller.dart';

class UserAvatar extends ConsumerWidget {
  final double size;
  const UserAvatar({super.key, this.size = 32});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(controllerProvider).value;
    final cacheSide = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(96, 960)
        .toInt();
    const fallback = 'assets/images/12225881.png';
    final encoded = settings?.profileImage ?? '';
    if (encoded.isNotEmpty) {
      try {
        return _circle(
          Image.memory(
            base64Decode(encoded),
            width: size,
            height: size,
            cacheWidth: cacheSide,
            cacheHeight: cacheSide,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(fallback, cacheSide),
          ),
        );
      } catch (_) {
        // Fall back to the built-in avatar if saved image data is invalid.
      }
    }
    final identity = ref.read(identityPort);
    final photoUrl = identity is ProfilePhotoIdentityService
        ? (identity as ProfilePhotoIdentityService).photoUrl
        : null;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return _circle(
        Image.network(
          photoUrl,
          width: size,
          height: size,
          cacheWidth: cacheSide,
          cacheHeight: cacheSide,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _fallback(fallback, cacheSide);
          },
          errorBuilder: (_, _, _) => _fallback(fallback, cacheSide),
        ),
      );
    }
    return _fallback(fallback, cacheSide);
  }

  Widget _circle(Widget image) => SizedBox.square(
    dimension: size,
    child: ClipOval(child: image),
  );

  Widget _fallback(String path, int cacheSide) => _circle(
    Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: cacheSide,
      cacheHeight: cacheSide,
    ),
  );
}
