import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';

/// Handles all local persistence — user profile AND the device token
/// used to scope every Supabase query.
class LocalStorageService {
  LocalStorageService._();

  // ─── Keys ────────────────────────────────────────────────────────────────
  static const _kIsLoggedIn   = 'is_logged_in';
  static const _kCurrentUser  = 'current_user';
  static const _kUsersMap     = 'users_map';
  static const _kDeviceToken  = 'device_token';
  static const _kSeeded       = 'default_user_seeded';

  // ─── Default user seed ───────────────────────────────────────────────────

  /// Ensures the default demo account exists on first run.
  static Future<void> seedDefaultUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeeded) == true) return;

    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    const defaultEmail    = 'user@gmail.com';
    const defaultPassword = '111111';
    const defaultDeviceId = 'STM32_DEVICE_001';

    if (!users.containsKey(defaultEmail)) {
      final user = UserModel(
        id:        'usr_default',
        fullName:  'Demo User',
        email:     defaultEmail,
        deviceId:  defaultDeviceId,
        createdAt: DateTime(2025, 1, 1),
      );
      users[defaultEmail] = {
        'password': defaultPassword,
        'user':     user.toJson(),
      };
      await prefs.setString(_kUsersMap, json.encode(users));
    }

    await prefs.setBool(_kSeeded, true);
  }

  // ─── Device Token ─────────────────────────────────────────────────────────

  static Future<void> saveDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceToken, token);
  }

  static Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Prefer the token stored on the user object
    final raw = prefs.getString(_kCurrentUser);
    if (raw != null) {
      final user = UserModel.fromJson(json.decode(raw) as Map<String, dynamic>);
      if (user.deviceId != null && user.deviceId!.isNotEmpty) {
        return user.deviceId;
      }
    }
    return prefs.getString(_kDeviceToken) ?? 'STM32_DEVICE_001';
  }

  static Future<void> clearDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeviceToken);
  }

  static Future<bool> isDevicePaired() async {
    final token = await getDeviceToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /// Register a new user (with device ID). Returns null on success or an error string.
  static Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    if (users.containsKey(email.toLowerCase())) {
      return 'An account with this email already exists.';
    }

    final user = UserModel(
      id:        'usr_${DateTime.now().millisecondsSinceEpoch}',
      fullName:  fullName.trim(),
      email:     email.toLowerCase().trim(),
      deviceId:  deviceId.trim(),
      createdAt: DateTime.now(),
    );

    users[email.toLowerCase()] = {
      'password': password,
      'user':     user.toJson(),
    };

    await prefs.setString(_kUsersMap, json.encode(users));
    // Save device token from the user's device ID
    await saveDeviceToken(deviceId.trim());
    await _setCurrentUser(prefs, user);
    return null;
  }

  /// Login with email + password. Returns null on success or an error string.
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    final entry = users[email.toLowerCase()];
    if (entry == null) return 'No account found with this email.';
    if (entry['password'] as String != password) return 'Incorrect password.';

    final user = UserModel.fromJson(entry['user'] as Map<String, dynamic>);
    // Sync device token from user's stored device ID
    if (user.deviceId != null && user.deviceId!.isNotEmpty) {
      await saveDeviceToken(user.deviceId!);
    }
    await _setCurrentUser(prefs, user);
    return null;
  }

  /// Sign out.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kCurrentUser);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCurrentUser);
    if (raw == null) return null;
    return UserModel.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  static Future<String?> updateProfile({
    required String fullName,
    required String email,
    String? deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getCurrentUser();
    if (current == null) return 'Not logged in.';

    final raw = prefs.getString(_kUsersMap);
    final Map<String, dynamic> users =
        raw != null ? json.decode(raw) as Map<String, dynamic> : {};

    final oldKey = current.email.toLowerCase();
    final newKey = email.toLowerCase().trim();

    if (newKey != oldKey && users.containsKey(newKey)) {
      return 'That email is already in use.';
    }

    final password = (users[oldKey]?['password'] as String?) ?? '';
    final newDeviceId = (deviceId != null && deviceId.trim().isNotEmpty)
        ? deviceId.trim()
        : current.deviceId;

    final updated = current.copyWith(
      fullName: fullName.trim(),
      email:    newKey,
      deviceId: newDeviceId,
    );

    users.remove(oldKey);
    users[newKey] = {'password': password, 'user': updated.toJson()};
    await prefs.setString(_kUsersMap, json.encode(users));
    await _setCurrentUser(prefs, updated);

    // Update the device token when device ID changes
    if (newDeviceId != null && newDeviceId.isNotEmpty) {
      await saveDeviceToken(newDeviceId);
    }
    return null;
  }

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

    final key   = current.email.toLowerCase();
    final entry = users[key];
    if (entry == null) return 'User data not found.';
    if (entry['password'] as String != currentPassword) {
      return 'Current password is incorrect.';
    }

    users[key] = {'password': newPassword, 'user': entry['user']};
    await prefs.setString(_kUsersMap, json.encode(users));
    return null;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  static Future<void> _setCurrentUser(
      SharedPreferences prefs, UserModel user) async {
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kCurrentUser, json.encode(user.toJson()));
  }
}
