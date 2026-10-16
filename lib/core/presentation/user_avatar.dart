import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/presentation/controller.dart';

class UserAvatar extends ConsumerWidget {
  final double size;
  const UserAvatar({super.key, this.size = 32});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ClipOval(
    child: Image.asset(
      ref.watch(controllerProvider).value?.testUser == true
          ? 'assets/images/test-user.webp'
          : 'assets/images/12225881.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: 144,
    ),
  );
}
