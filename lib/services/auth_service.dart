import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

/// Thrown when an account does not exist in the database.
class AccountNotFoundException implements Exception {
  final String identifier;
  final String message;
  const AccountNotFoundException(this.identifier, [this.message = 'No account found in database.']);
  @override
  String toString() => message;
}

/// Generic authentication exception.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Represents the authenticated user.
class AuthUser {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final bool isGoogleUser;

  const AuthUser({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.isGoogleUser = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'isGoogleUser': isGoogleUser,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int?,
        name: json['name'] as String? ?? json['displayName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isGoogleUser: json['isGoogleUser'] as bool? ?? false,
      );
}

/// Manages authentication with database verification and registration.
class AuthService {
  static const String _keyAuthUser = 'auth_user';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ── Database Sign-In ─────────────────────────────────────────

  /// Signs in against the PostgreSQL database using phone or email.
  /// If the account does not exist in the database, throws [AccountNotFoundException].
  static Future<AuthUser> loginWithDatabase(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      throw const AuthException('Please enter a phone number or email.');
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/auth/login');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': cleanId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;

        final user = AuthUser(
          id: userData['id'] as int?,
          name: (userData['name'] as String? ?? '').isNotEmpty
              ? userData['name'] as String
              : cleanId,
          phone: userData['phone'] as String? ?? cleanId,
          email: userData['email'] as String?,
        );

        await _persistUser(user);
        await _syncProfile(user);
        return user;
      } else if (response.statusCode == 404) {
        throw AccountNotFoundException(
          cleanId,
          'No account found in database for "$cleanId".',
        );
      } else {
        String msg = 'Login failed (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err.containsKey('detail')) {
            msg = err['detail'].toString();
          }
        } catch (_) {}
        throw AuthException(msg);
      }
    } on AccountNotFoundException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed to fetch') || msg.contains('xmlhttprequest') || msg.contains('connection refused')) {
        throw const AuthException('Cannot reach Dr. Gut server. Please ensure the backend is running.');
      }
      throw AuthException('Sign-in error: $e');
    }
  }

  // ── Database Account Creation (Registration) ──────────────────

  /// Registers a brand new user account directly in PostgreSQL.
  static Future<AuthUser> registerAccount({
    required String name,
    required String phone,
    String? email,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanEmail = email?.trim().isEmpty ?? true ? null : email!.trim();

    if (cleanName.isEmpty) throw const AuthException('Please enter your full name.');
    if (cleanPhone.isEmpty) throw const AuthException('Please enter your phone number.');

    final uri = Uri.parse('${AppConfig.baseUrl}/auth/register');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': cleanName,
              'phone': cleanPhone,
              'email': cleanEmail,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;

        final user = AuthUser(
          id: userData['id'] as int?,
          name: userData['name'] as String? ?? cleanName,
          phone: userData['phone'] as String? ?? cleanPhone,
          email: userData['email'] as String? ?? cleanEmail,
        );

        await _persistUser(user);
        await _syncProfile(user);
        return user;
      } else {
        String msg = 'Account creation failed (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err.containsKey('detail')) {
            msg = err['detail'].toString();
          }
        } catch (_) {}
        throw AuthException(msg);
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed to fetch') || msg.contains('xmlhttprequest')) {
        throw const AuthException('Cannot reach Dr. Gut server. Please ensure backend is running.');
      }
      throw AuthException('Registration error: $e');
    }
  }

  // ── Check if Account Exists ───────────────────────────────────

  /// Checks if an identifier exists in the database.
  static Future<bool> checkAccountExists(String identifier) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/check/${Uri.encodeComponent(identifier.trim())}');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['exists'] as bool? ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────

  /// Triggers the Google sign-in flow. Returns [AuthUser] on success, null on cancel.
  static Future<AuthUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final email = account.email;
      final name = account.displayName ?? email.split('@').first;

      // Try checking if this Google email already exists in DB
      try {
        return await loginWithDatabase(email);
      } on AccountNotFoundException {
        // Return a temporary Google AuthUser so caller knows user needs account creation
        final user = AuthUser(
          name: name,
          phone: '',
          email: email,
          photoUrl: account.photoUrl,
          isGoogleUser: true,
        );
        return user;
      }
    } catch (e) {
      return null;
    }
  }

  /// Legacy email helper
  static Future<AuthUser> signInWithEmail(String email) async {
    return await loginWithDatabase(email);
  }

  /// Legacy Google fallback helper
  static Future<AuthUser> signInAsGoogle(String email) async {
    try {
      return await loginWithDatabase(email);
    } on AccountNotFoundException {
      final user = AuthUser(
        name: email.trim().split('@').first,
        phone: '',
        email: email.trim(),
        isGoogleUser: true,
      );
      return user;
    }
  }

  // ── Session helpers ─────────────────────────────────────────

  /// Returns the currently saved user, if any.
  static Future<AuthUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAuthUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Whether a user session exists.
  static Future<bool> isLoggedIn() async {
    return (await getCurrentUser()) != null;
  }

  /// Signs out — clears local session + Google session.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthUser);
  }

  // ── Private Helpers ─────────────────────────────────────────

  static Future<void> _persistUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthUser, jsonEncode(user.toJson()));
  }

  static Future<void> _syncProfile(AuthUser user) async {
    final existing = await StorageService.loadProfile();
    final updated = (existing ?? const UserProfile(
      name: '',
      phone: '',
      locationName: 'Madurai, Tamil Nadu, India',
      lat: 9.919,
      lng: 78.1195,
      budget: 250,
    )).copyWith(
      name: user.name.isNotEmpty ? user.name : existing?.name,
      phone: user.phone.isNotEmpty ? user.phone : existing?.phone,
    );
    await StorageService.saveProfile(updated);
  }
}
