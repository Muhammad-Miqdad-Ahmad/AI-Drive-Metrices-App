import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';

/// Handles all local persistence for authentication and user profile.
class LocalStorageService {
  LocalStorageService._();

  // ─── Keys ────────────────────────────────────────────────────────────────
  static const _kIsLoggedIn   = 'is_logged_in';
  static const _kCurrentUser  = 'current_user';
  static const _kUsersMap     = 'users_map'; // email → {password, user json}

  // ─── Auth ────────────────────────────────────────────────────────────────

  /// Register a new user. Returns `null` on success, or an error string.
  static Future<String?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    if (users.containsKey(email.toLowerCase())) {
      return 'An account with this email already exists.';
    }

    final user = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.toLowerCase().trim(),
      createdAt: DateTime.now(),
    );

    users[email.toLowerCase()] = {
      'password': password,
      'user': user.toJson(),
    };

    await prefs.setString(_kUsersMap, json.encode(users));
    await _setCurrentUser(prefs, user);
    return null; // success
  }

  /// Login with email + password. Returns `null` on success, or an error string.
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    final entry = users[email.toLowerCase()];
    if (entry == null) {
      return 'No account found with this email.';
    }
    if (entry['password'] as String != password) {
      return 'Incorrect password.';
    }

    final user =
        UserModel.fromJson(entry['user'] as Map<String, dynamic>);
    await _setCurrentUser(prefs, user);
    return null; // success
  }

  /// Sign out the current user.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kCurrentUser);
  }

  /// Whether a user is currently signed in.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  // ─── Profile ─────────────────────────────────────────────────────────────

  /// Get the currently logged-in user, or null.
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCurrentUser);
    if (raw == null) return null;
    return UserModel.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  /// Update name and/or email for the current user.
  static Future<String?> updateProfile({
    required String fullName,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getCurrentUser();
    if (current == null) return 'Not logged in.';

    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    final oldKey = current.email.toLowerCase();
    final newKey = email.toLowerCase().trim();

    // If email changed, check it's not taken by someone else
    if (newKey != oldKey && users.containsKey(newKey)) {
      return 'That email is already in use.';
    }

    final password = (users[oldKey]?['password'] as String?) ?? '';
    final updated = current.copyWith(
      fullName: fullName.trim(),
      email: newKey,
    );

    // Re-key in users map
    users.remove(oldKey);
    users[newKey] = {'password': password, 'user': updated.toJson()};
    await prefs.setString(_kUsersMap, json.encode(users));
    await _setCurrentUser(prefs, updated);
    return null; // success
  }

  /// Change password for the currently logged-in user.
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getCurrentUser();
    if (current == null) return 'Not logged in.';

    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    final key = current.email.toLowerCase();
    final entry = users[key];
    if (entry == null) return 'User data not found.';
    if (entry['password'] as String != currentPassword) {
      return 'Current password is incorrect.';
    }

    users[key] = {
      'password': newPassword,
      'user': entry['user'],
    };
    await prefs.setString(_kUsersMap, json.encode(users));
    return null; // success
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  static Future<void> _setCurrentUser(
      SharedPreferences prefs, UserModel user) async {
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kCurrentUser, json.encode(user.toJson()));
  }
}
