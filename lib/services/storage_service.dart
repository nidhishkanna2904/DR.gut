import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diet_plan.dart';
import '../models/user_profile.dart';

class StorageService {
  static const String _keySeenLanding = 'seen_landing';
  static const String _keyProfile = 'saved_user_profile';
  static const String _keyPlan = 'saved_diet_plan';

  static Future<bool> hasSeenLanding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeenLanding) ?? false;
  }

  static Future<void> setSeenLanding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeenLanding, value);
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }

  static Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlan(DietPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlan, jsonEncode(plan.toJson()));
  }

  static Future<DietPlan?> loadLastPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlan);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DietPlan.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
  }
}
