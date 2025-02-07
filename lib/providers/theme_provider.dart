import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs.getBool(_themeKey) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Tema yüklenirken hata oluştu: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      await _prefs.setBool(_themeKey, _isDarkMode);
      notifyListeners();
    } catch (e) {
      debugPrint('Tema değiştirilirken hata oluştu: $e');
    }
  }

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.grey[800],
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.grey[800],
      ),
    ),
    iconTheme: IconThemeData(
      color: Colors.blue[700],
    ),
    extensions: [
      CustomColors(
        success: Colors.green[50]!,
        error: Colors.red[50]!,
        neutral: Colors.grey[50]!,
        cardText: Colors.grey[800]!,
        positiveBalance: Colors.green[700]!,
        negativeBalance: Colors.red[700]!,
      ),
    ],
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.grey[200],
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[200],
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.grey[200],
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.grey[200],
      ),
    ),
    iconTheme: IconThemeData(
      color: Colors.blue[200],
    ),
    extensions: [
      CustomColors(
        success: Colors.green[900]!,
        error: Colors.red[900]!,
        neutral: Colors.grey[900]!,
        cardText: Colors.grey[200]!,
        positiveBalance: Colors.green[300]!,
        negativeBalance: Colors.red[300]!,
      ),
    ],
  );
}

// Özel renk sınıfı
class CustomColors extends ThemeExtension<CustomColors> {
  final Color success;
  final Color error;
  final Color neutral;
  final Color cardText;
  final Color positiveBalance;
  final Color negativeBalance;

  CustomColors({
    required this.success,
    required this.error,
    required this.neutral,
    required this.cardText,
    required this.positiveBalance,
    required this.negativeBalance,
  });

  @override
  ThemeExtension<CustomColors> copyWith({
    Color? success,
    Color? error,
    Color? neutral,
    Color? cardText,
    Color? positiveBalance,
    Color? negativeBalance,
  }) {
    return CustomColors(
      success: success ?? this.success,
      error: error ?? this.error,
      neutral: neutral ?? this.neutral,
      cardText: cardText ?? this.cardText,
      positiveBalance: positiveBalance ?? this.positiveBalance,
      negativeBalance: negativeBalance ?? this.negativeBalance,
    );
  }

  @override
  ThemeExtension<CustomColors> lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      cardText: Color.lerp(cardText, other.cardText, t)!,
      positiveBalance: Color.lerp(positiveBalance, other.positiveBalance, t)!,
      negativeBalance: Color.lerp(negativeBalance, other.negativeBalance, t)!,
    );
  }
}