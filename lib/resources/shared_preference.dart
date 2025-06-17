import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefHelper {
  static const String _introSeenKey = 'intro_seen';
  static const String _isLoggedInKey = 'is_logged_in';

  static Future<void> setIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
    debugPrint('SharedPrefHelper: intro_seen set to true');
  }

  static Future<bool> isIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_introSeenKey) ?? false;
    debugPrint('SharedPrefHelper: intro_seen = $seen');
    return seen;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
    debugPrint('SharedPrefHelper: is_logged_in set to $value');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    debugPrint('SharedPrefHelper: is_logged_in = $loggedIn');
    return loggedIn;
  }
}