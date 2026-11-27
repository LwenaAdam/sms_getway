import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get isUsingSystemTheme => _themeMode == ThemeMode.system;

  bool get isLoading => _isLoading;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // If following device theme, automatically update app when phone flips theme
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  void _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('isDarkMode')) {
        final isDark = prefs.getBool('isDarkMode');
        if (isDark != null) {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
      } else {
        // By default on start: Follow device system theme!
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    // Prevent multiple rapid toggles
    if (_isLoading) {
      debugPrint('⏳ Theme toggle already in progress, ignoring request');
      return;
    }

    _isLoading = true;
    debugPrint('🔄 Starting theme toggle...');

    try {
      final currentlyDark = isDarkMode;
      final newMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;

      // Save preference FIRST before updating state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
      debugPrint(
          '✅ Theme preference saved: ${newMode == ThemeMode.dark ? "Dark" : "Light"}');

      // Small delay to ensure SharedPreferences write is truly complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Update state only AFTER successful save
      _themeMode = newMode;
      notifyListeners();
      debugPrint('🎨 Theme updated and listeners notified');
    } catch (e) {
      debugPrint('❌ Error toggling theme: $e');
    } finally {
      _isLoading = false;
      debugPrint('✓ Theme toggle complete');
    }
  }

  Future<void> resetToSystemTheme() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isDarkMode');
      _themeMode = ThemeMode.system;
      notifyListeners();
      debugPrint('🎨 Theme reset to follow device system theme');
    } catch (e) {
      debugPrint('❌ Error resetting theme to system: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_isLoading) {
      debugPrint('⏳ Theme change already in progress, ignoring request');
      return;
    }

    if (_themeMode == mode) {
      debugPrint(
          'ℹ️ Already in ${mode == ThemeMode.dark ? "dark" : mode == ThemeMode.light ? "light" : "system"} mode');
      return;
    }

    _isLoading = true;
    debugPrint(
        '🔄 Starting theme change to ${mode == ThemeMode.dark ? "dark" : mode == ThemeMode.light ? "light" : "system"}...');

    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.system) {
        await prefs.remove('isDarkMode');
      } else {
        await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      _themeMode = mode;
      notifyListeners();
      debugPrint('🎨 Theme changed and listeners notified');
    } catch (e) {
      debugPrint('❌ Error setting theme mode: $e');
    } finally {
      _isLoading = false;
      debugPrint('✓ Theme change complete');
    }
  }
}
