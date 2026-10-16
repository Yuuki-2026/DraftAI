import 'strings.dart';

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF131313),
      low = Color(0xFF1C1B1B),
      mid = Color(0xFF201F1F),
      high = Color(0xFF2A2A2A),
      line = Color(0xFF393939),
      text = Color(0xFFF5F5F5),
      muted = Color(0xFFA0A0A0);
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Colors.grey,
        brightness: brightness,
      ).copyWith(
        primary: dark ? Colors.white : Colors.black,
        onPrimary: dark ? Colors.black : Colors.white,
        secondary: dark ? Colors.white : Colors.black,
        onSecondary: dark ? Colors.black : Colors.white,
        secondaryContainer: dark ? AppColors.high : const Color(0xFFEEEEEE),
        onSecondaryContainer: dark ? AppColors.text : const Color(0xFF171717),
        tertiary: dark ? Colors.white : Colors.black,
        onTertiary: dark ? Colors.black : Colors.white,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: dark ? AppColors.background : Colors.white,
        surfaceContainerLow: dark ? AppColors.low : const Color(0xFFF5F5F5),
        surfaceContainer: dark ? AppColors.mid : const Color(0xFFF0F0F0),
        surfaceContainerHigh: dark ? AppColors.high : const Color(0xFFEAEAEA),
        surfaceContainerHighest: dark
            ? const Color(0xFF353534)
            : const Color(0xFFE2E2E2),
        surface: dark ? AppColors.background : const Color(0xFFFAFAFA),
        onSurface: dark ? AppColors.text : const Color(0xFF171717),
        onSurfaceVariant: dark
            ? const Color(0xFFD0D0D0)
            : const Color(0xFF424242),
        outline: dark ? AppColors.line : const Color(0xFF8F8F8F),
        outlineVariant: dark
            ? const Color(0xFF393939)
            : const Color(0xFFB0B0B0),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurface),
      bodySmall: TextStyle(
        fontSize: 11,
        height: 1.5,
        color: dark ? AppColors.muted : const Color(0xFF555555),
      ),
      titleLarge: TextStyle(
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? Colors.white : const Color(0xFF111111),
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.low : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
      backgroundColor: dark ? AppColors.low : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      surfaceTintColor: Colors.transparent,
      backgroundColor: dark ? AppColors.low : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

abstract final class Breakpoints {
  static const medium = 600.0, expanded = 840.0;
  static int columns(double width) => width >= expanded ? 2 : 1;
}

class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1000});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: c.maxWidth < Breakpoints.medium ? 16 : 24,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(13),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? AppColors.low
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class Meta extends StatelessWidget {
  final String text;
  const Meta(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'JetBrainsMono', fontSize: 10),
  );
}

class Pill extends StatelessWidget {
  final String text;
  const Pill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Meta(text),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? action;
  const SectionTitle(this.text, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            tr(context, text),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?action,
      ],
    ),
  );
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, '$e'))));
    }
  }
}

void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, text))));
Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, title)),
        content: Text(tr(context, text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr(context, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(context, 'Confirmar')),
          ),
        ],
      ),
    ) ??
    false;
void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
String dateLabel(DateTime d) {
  final v = d.toLocal();
  return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
}

String byteLabel(int b) => b < 1024
    ? '$b B'
    : b < 1024 * 1024
    ? '${(b / 1024).toStringAsFixed(1)} KB'
    : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

/// Filled folder colour with a visible outline even for white on light surfaces.
class FolderGlyph extends StatelessWidget {
  final int color;
  final double size;
  const FolderGlyph(this.color, {super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Icon(Icons.folder, color: Color(color), size: size),
        Icon(
          Icons.folder_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .38),
          size: size,
        ),
      ],
    ),
  );
}
