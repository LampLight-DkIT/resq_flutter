import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF00A7A7), // Vibrant teal
      surfaceTint: Color(0xFF00A7A7),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFB2F1F1),
      onPrimaryContainer: Color(0xFF004949),

      secondary: Color(0xFFFF6B6B), // Coral red
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFD1D1),
      onSecondaryContainer: Color(0xFF8A1F1F),

      tertiary: Color(0xFFFFC107), // Citrus yellow
      onTertiary: Color(0xFF000000),
      tertiaryContainer: Color(0xFFFFF3C1),
      onTertiaryContainer: Color(0xFF5C4700),

      error: Color(0xFFD32F2F),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD4),
      onErrorContainer: Color(0xFF5C1B1B),

      surface: Color(0xFFF7FAFA),
      onSurface: Color(0xFF121212),
      onSurfaceVariant: Color(0xFF4A4A4A),

      outline: Color(0xFF8C8C8C),
      outlineVariant: Color(0xFFD6D6D6),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),

      inverseSurface: Color(0xFF2E3A3A),
      inversePrimary: Color(0xFF63DCDC),

      primaryFixed: Color(0xFFB2F1F1),
      onPrimaryFixed: Color(0xFF002B2B),
      primaryFixedDim: Color(0xFF63DCDC),
      onPrimaryFixedVariant: Color(0xFF004949),

      secondaryFixed: Color(0xFFFFD1D1),
      onSecondaryFixed: Color(0xFF3B0000),
      secondaryFixedDim: Color(0xFFFF8C8C),
      onSecondaryFixedVariant: Color(0xFF8A1F1F),

      tertiaryFixed: Color(0xFFFFF3C1),
      onTertiaryFixed: Color(0xFF302600),
      tertiaryFixedDim: Color(0xFFFFE172),
      onTertiaryFixedVariant: Color(0xFF5C4700),

      surfaceDim: Color(0xFFD5E0E0),
      surfaceBright: Color(0xFFF7FAFA),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFE9F0F0),
      surfaceContainer: Color(0xFFE0E7E7),
      surfaceContainerHigh: Color(0xFFD7DEDE),
      surfaceContainerHighest: Color(0xFFCED6D6),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff00395d),
      surfaceTint: Color(0xff30628c),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff40719c),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff433400),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff826a1c),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003d43),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff177882),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff5e2324),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffa15857),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff5fafb),
      onSurface: Color(0xff0c1213),
      onSurfaceVariant: Color(0xff36372b),
      outline: Color(0xff535346),
      outlineVariant: Color(0xff6e6e60),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2b3133),
      inversePrimary: Color(0xff9ccbfb),
      primaryFixed: Color(0xff40719c),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff245882),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff826a1c),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff685200),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff177882),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff005e67),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc2c7c9),
      surfaceBright: Color(0xfff5fafb),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff5f6),
      surfaceContainer: Color(0xffe3e9ea),
      surfaceContainerHigh: Color(0xffd8dedf),
      surfaceContainerHighest: Color(0xffcdd3d4),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002e4d),
      surfaceTint: Color(0xff30628c),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff144c76),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff372b00),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff5a4700),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003237),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff005159),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff51191b),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff763535),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff5fafb),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff2c2d22),
      outlineVariant: Color(0xff494a3d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2b3133),
      inversePrimary: Color(0xff9ccbfb),
      primaryFixed: Color(0xff144c76),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff003557),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff5a4700),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff3f3100),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff005159),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff00393e),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb4babb),
      surfaceBright: Color(0xfff5fafb),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffecf2f3),
      surfaceContainer: Color(0xffdee3e5),
      surfaceContainerHigh: Color(0xffcfd5d6),
      surfaceContainerHighest: Color(0xffc2c7c9),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff9ccbfb),
      surfaceTint: Color(0xff9ccbfb),
      onPrimary: Color(0xff003354),
      primaryContainer: Color(0xff104a73),
      onPrimaryContainer: Color(0xffcee5ff),
      secondary: Color(0xffe2c46d),
      onSecondary: Color(0xff3c2f00),
      secondaryContainer: Color(0xff574500),
      onSecondaryContainer: Color(0xffffe088),
      tertiary: Color(0xff81d3de),
      onTertiary: Color(0xff00363c),
      tertiaryContainer: Color(0xff004f56),
      onTertiaryContainer: Color(0xff9df0fb),
      error: Color(0xffffb3b1),
      onError: Color(0xff571d1f),
      errorContainer: Color(0xff733333),
      onErrorContainer: Color(0xffffdad8),
      surface: Color(0xff0e1415),
      onSurface: Color(0xffdee3e5),
      onSurfaceVariant: Color(0xffc8c7b7),
      outline: Color(0xff929282),
      outlineVariant: Color(0xff47483b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e5),
      inversePrimary: Color(0xff30628c),
      primaryFixed: Color(0xffcee5ff),
      onPrimaryFixed: Color(0xff001d33),
      primaryFixedDim: Color(0xff9ccbfb),
      onPrimaryFixedVariant: Color(0xff104a73),
      secondaryFixed: Color(0xffffe088),
      onSecondaryFixed: Color(0xff241a00),
      secondaryFixedDim: Color(0xffe2c46d),
      onSecondaryFixedVariant: Color(0xff574500),
      tertiaryFixed: Color(0xff9df0fb),
      onTertiaryFixed: Color(0xff001f23),
      tertiaryFixedDim: Color(0xff81d3de),
      onTertiaryFixedVariant: Color(0xff004f56),
      surfaceDim: Color(0xff0e1415),
      surfaceBright: Color(0xff343a3b),
      surfaceContainerLowest: Color(0xff090f10),
      surfaceContainerLow: Color(0xff171d1e),
      surfaceContainer: Color(0xff1b2122),
      surfaceContainerHigh: Color(0xff252b2c),
      surfaceContainerHighest: Color(0xff303637),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffc3dfff),
      surfaceTint: Color(0xff9ccbfb),
      onPrimary: Color(0xff002843),
      primaryContainer: Color(0xff6695c2),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfff9da80),
      onSecondary: Color(0xff302400),
      secondaryContainer: Color(0xffa98e3d),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xff97e9f5),
      onTertiary: Color(0xff002b2f),
      tertiaryContainer: Color(0xff489da7),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2d0),
      onError: Color(0xff481315),
      errorContainer: Color(0xffcb7a79),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff0e1415),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffdeddcc),
      outline: Color(0xffb3b3a3),
      outlineVariant: Color(0xff919182),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e5),
      inversePrimary: Color(0xff124b74),
      primaryFixed: Color(0xffcee5ff),
      onPrimaryFixed: Color(0xff001223),
      primaryFixedDim: Color(0xff9ccbfb),
      onPrimaryFixedVariant: Color(0xff00395d),
      secondaryFixed: Color(0xffffe088),
      onSecondaryFixed: Color(0xff171000),
      secondaryFixedDim: Color(0xffe2c46d),
      onSecondaryFixedVariant: Color(0xff433400),
      tertiaryFixed: Color(0xff9df0fb),
      onTertiaryFixed: Color(0xff001417),
      tertiaryFixedDim: Color(0xff81d3de),
      onTertiaryFixedVariant: Color(0xff003d43),
      surfaceDim: Color(0xff0e1415),
      surfaceBright: Color(0xff3f4647),
      surfaceContainerLowest: Color(0xff040809),
      surfaceContainerLow: Color(0xff191f20),
      surfaceContainer: Color(0xff23292a),
      surfaceContainerHigh: Color(0xff2d3435),
      surfaceContainerHighest: Color(0xff393f40),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffe7f1ff),
      surfaceTint: Color(0xff9ccbfb),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff98c7f7),
      onPrimaryContainer: Color(0xff000c19),
      secondary: Color(0xffffefc9),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffdec069),
      onSecondaryContainer: Color(0xff100b00),
      tertiary: Color(0xffc9f8ff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xff7dcfda),
      onTertiaryContainer: Color(0xff000e10),
      error: Color(0xffffecea),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffadab),
      onErrorContainer: Color(0xff220002),
      surface: Color(0xff0e1415),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xfff2f1df),
      outlineVariant: Color(0xffc4c3b3),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e5),
      inversePrimary: Color(0xff124b74),
      primaryFixed: Color(0xffcee5ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff9ccbfb),
      onPrimaryFixedVariant: Color(0xff001223),
      secondaryFixed: Color(0xffffe088),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffe2c46d),
      onSecondaryFixedVariant: Color(0xff171000),
      tertiaryFixed: Color(0xff9df0fb),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xff81d3de),
      onTertiaryFixedVariant: Color(0xff001417),
      surfaceDim: Color(0xff0e1415),
      surfaceBright: Color(0xff4b5152),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1b2122),
      surfaceContainer: Color(0xff2b3133),
      surfaceContainerHigh: Color(0xff363c3e),
      surfaceContainerHighest: Color(0xff424849),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
      );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
