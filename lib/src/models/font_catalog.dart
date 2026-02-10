class FontCatalog {
  /// Full list of available fonts, alphabetical.
  static const List<String> allFonts = [
    'Amatic SC',
    'Arial',
    'Calibri',
    'Caveat',
    'Century Gothic',
    'Comfortaa',
    'Comic Sans MS',
    'Courier New',
    'EB Garamond',
    'Georgia',
    'Impact',
    'Lato',
    'Lobster',
    'Montserrat',
    'Open Sans',
    'Oswald',
    'Pacifico',
    'Playfair Display',
    'Raleway',
    'Roboto',
    'Roboto Mono',
    'Times New Roman',
    'Trebuchet MS',
    'Ubuntu',
    'Verdana',
  ];

  /// Fonts that need loading via the google_fonts package.
  static const Set<String> googleFonts = {
    'Amatic SC',
    'Caveat',
    'Comfortaa',
    'EB Garamond',
    'Lato',
    'Lobster',
    'Montserrat',
    'Open Sans',
    'Oswald',
    'Pacifico',
    'Playfair Display',
    'Raleway',
    'Roboto',
    'Roboto Mono',
    'Ubuntu',
  };

  /// Whether this font needs loading via the google_fonts package.
  static bool isGoogleFont(String name) => googleFonts.contains(name);
}
