class AppImages {
  // Main app logo
  static const String logo = 'assets/scraps.png';
  static const String icon = 'assets/scraps_icon.png';
  static const String splash = 'assets/scraps_splash.png';
  static const String oldLogo = 'assets/ecg_logo.png';

  // Image dimensions for different use cases
  static const Map<String, double> dimensions = {
    'splash': 120.0,
    'onboarding': 180.0,
    'drawer': 60.0,
    'appbar': 32.0,
    'icon': 24.0,
  };

  // Get the appropriate image based on context
  static String getImageForContext(String context) {
    switch (context) {
      case 'splash':
        return splash;
      case 'onboarding':
        return logo;
      case 'drawer':
        return icon;
      case 'appbar':
        return icon;
      default:
        return logo;
    }
  }

  // Get dimensions for specific context
  static double getDimensionForContext(String context) {
    return dimensions[context] ?? 32.0;
  }
}
