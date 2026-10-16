import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Persistencia local (preferencias) para token, sesión, avatar y
// disponibilidad del trabajador. Se usa mientras Supabase opera en modo mock.
class StorageService {
  static const _tokenKey = 'token';
  static const _sessionKey = 'auth_session';
  static const _availabilityKey = 'worker_availability';
  static const _twoFactorKey = 'two_factor_enabled';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- Sesión (AuthState serializado) ---

  static Future<Map<String, dynamic>?> loadSessionMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSessionMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(map));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // --- Disponibilidad del trabajador ---

  static Future<bool> getAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_availabilityKey) ?? true;
  }

  static Future<void> setAvailability(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_availabilityKey, value);
  }

  // --- Segundo factor (2FA), se conserva entre sesiones ---

  static Future<bool> getTwoFactorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_twoFactorKey) ?? false;
  }

  static Future<void> setTwoFactorEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_twoFactorKey, value);
  }
}
