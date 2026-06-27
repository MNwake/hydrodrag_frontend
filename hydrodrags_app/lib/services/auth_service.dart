import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../utils/app_log.dart';
import '../utils/secure_storage_config.dart';

/// Authentication state
enum AuthStatus {
  unauthenticated,
  authenticated,
  codeSent,
  verifying,
  serverUnavailable,
}

/// Response model for verify code endpoint
class VerifyCodeResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool? profileComplete; // Nullable because refresh endpoint might not return it

  VerifyCodeResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.profileComplete,
  });

  factory VerifyCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifyCodeResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      profileComplete: json['profile_complete'] as bool?,
    );
  }
}

/// AuthService manages passwordless email authentication
class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = appSecureStorage;
  
  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _emailKey = 'user_email';
  static const String _profileCompleteKey = 'profile_complete';
  
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _email;
  String? _accessToken;
  String? _errorMessage;
  bool _isLoading = false;
  bool _profileComplete = false;
  Future<bool>? _refreshInProgress;

  AuthStatus get status => _status;
  String? get email => _email;
  String? get accessToken => _accessToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get profileComplete => _profileComplete;
  bool get isServerUnavailable => _status == AuthStatus.serverUnavailable;

  AuthService() {
    _checkExistingAuth();
  }

  /// Check if server is available
  Future<bool> _checkServerHealth() async {
    try {

      final response = await LoggedHttp.get(
        Uri.parse(ApiConfig.healthEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final isHealthy = body['status'] == 'ok';
        return isHealthy;
      }
      return false;
    } catch (e, stack) {
      AppLog.error('Auth', 'Health check failed', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Check for existing authentication on app launch
  Future<void> _checkExistingAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      // First check if server is available
      final serverAvailable = await _checkServerHealth();
      
      if (!serverAvailable) {
        // Server is not available - don't authenticate with stored tokens
        _status = AuthStatus.serverUnavailable;
        _errorMessage = 'Server is unavailable. Please check your connection.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final token = await _secureStorage.read(key: _tokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final storedEmail = await _secureStorage.read(key: _emailKey);

      if (refreshToken != null) {
        // Always try to refresh on app start to get a fresh access token
        // This ensures the user stays logged in indefinitely
        // We can refresh even if email is missing - we'll fetch it from /me after refresh
        final refreshed = await refreshTokenIfNeeded();
        if (refreshed) {
          // Get the updated access token
          _accessToken = await _secureStorage.read(key: _tokenKey);
          
          // Get email - use stored if available, otherwise fetch from /me
          String? emailToUse = storedEmail;
          if (emailToUse == null && _accessToken != null) {
            emailToUse = await _fetchEmailFromMe();
            if (emailToUse != null) {
              // Store the recovered email
              await _secureStorage.write(key: _emailKey, value: emailToUse);
            }
          }
          
          _email = emailToUse ?? storedEmail;
          
          // Load profile completion status
          final profileCompleteStr = await _secureStorage.read(key: _profileCompleteKey);
          _profileComplete = profileCompleteStr == 'true';
          _status = AuthStatus.authenticated;
          _errorMessage = null;
          AppLog.info('Auth', 'User signed in');
        } else {
          // Refresh failed (400/401 or network) - _refreshToken already cleared on 400/401
          _status = AuthStatus.unauthenticated;
        }
      } else if (token != null && storedEmail != null) {
        // Fallback: access token but no refresh token - can't persist, clear
        await _clearAuth();
        _status = AuthStatus.unauthenticated;
      } else {
        // No stored credentials - don't clear (nothing to clear)
        AppLog.debug('Auth', 'No stored refresh token on startup');
        _status = AuthStatus.unauthenticated;
      }
    } catch (e, stack) {
      AppLog.error('Auth', 'Auto-login failed', error: e, stackTrace: stack, recoverable: true);
      // Transient error (storage, network) - do NOT clear auth; keep tokens for retry
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if we have valid tokens for the given email and authenticate
  /// Returns true if authentication was successful, false otherwise
  Future<bool> tryAuthenticateWithExistingTokens(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if we have stored tokens for this email
      final storedEmail = await _secureStorage.read(key: _emailKey);
      if (storedEmail == null || storedEmail.toLowerCase() != normalizedEmail) {
        // No tokens for this email, or different email
        // Clear any existing tokens for a different email
        if (storedEmail != null && storedEmail.toLowerCase() != normalizedEmail) {
          await _clearAuth();
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // We have tokens for this email, try to refresh them (serialized)
      final refreshed = await refreshTokenIfNeeded();
      if (refreshed) {
        // Refresh successful - we're authenticated
        _email = storedEmail;
        _accessToken = await _secureStorage.read(key: _tokenKey);
        final profileCompleteStr = await _secureStorage.read(key: _profileCompleteKey);
        _profileComplete = profileCompleteStr == 'true';
        _status = AuthStatus.authenticated;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        // Refresh failed - tokens are invalid/expired
        // Clear auth and return false (will need to send code)
        await _clearAuth();
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e, stack) {
      AppLog.error('Auth', 'Token authentication failed', error: e, stackTrace: stack, recoverable: true);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Request verification code for email
  Future<bool> requestVerificationCode(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      _errorMessage = 'Invalid email format';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _email = normalizedEmail;
    notifyListeners();

    try {
      final requestBody = jsonEncode({'email': normalizedEmail});

      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.requestCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response to verify it's valid
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'sent') {
          _status = AuthStatus.codeSent;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'Unexpected response from server. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Try to parse error message from response
        try {
          final errorBody = jsonDecode(response.body);
          _errorMessage = errorBody['detail'] ?? 
                         errorBody['message'] ?? 
                         'Failed to send code. Please try again.';
        } catch (_) {
          _errorMessage = 'Failed to send code. Please try again.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on http.ClientException catch (e, stack) {
      AppLog.error('Auth', 'Failed to request verification code', error: e, stackTrace: stack, recoverable: true);
      _errorMessage = 'Network error: ${e.message}. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      AppLog.error('Auth', 'Failed to request verification code', error: e, stackTrace: stack, recoverable: true);
      _errorMessage = 'Network error. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify code and complete authentication
  Future<bool> verifyCode(String code) async {
    if (code.isEmpty) {
      _errorMessage = 'Please enter a verification code';
      notifyListeners();
      return false;
    }

    if (_email == null) {
      _errorMessage = 'No email found. Please start over.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _status = AuthStatus.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      final requestBody = jsonEncode({
        'email': _email,
        'code': code,
      });

      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.verifyCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        // Parse the VerifyCodeResponse
        final responseBody = jsonDecode(response.body);
        final tokens = VerifyCodeResponse.fromJson(responseBody);
        
        _accessToken = tokens.accessToken;
        final refreshToken = tokens.refreshToken;
        // Use profileComplete from response, default to false if not provided
        _profileComplete = tokens.profileComplete ?? false;

        // Store tokens securely
        try {
          await _secureStorage.write(key: _tokenKey, value: _accessToken);
          await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
          await _secureStorage.write(key: _emailKey, value: _email);
          await _secureStorage.write(key: _profileCompleteKey, value: _profileComplete.toString());
        } catch (e, stack) {
          AppLog.error(
            'Auth',
            'Failed to persist auth tokens',
            error: e,
            stackTrace: stack,
            recoverable: true,
          );
        }

        // Double-check profile completion status by calling /me endpoint
        // This ensures we have the most up-to-date status from the backend
        try {
          final profileStatus = await _checkProfileCompletionStatus();
          if (profileStatus != null) {
            _profileComplete = profileStatus;
            await _secureStorage.write(key: _profileCompleteKey, value: _profileComplete.toString());
          }
        } catch (e) {
          // If /me endpoint fails, use the value from verify-code response
        }

          _status = AuthStatus.authenticated;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          AppLog.info('Auth', 'User signed in');
          return true;
      } else {
        // Try to parse error message from response
        try {
          final errorBody = jsonDecode(response.body);
          _errorMessage = errorBody['detail'] ?? 
                         errorBody['message'] ?? 
                         'Invalid or expired code. Please try again.';
        } catch (_) {
          _errorMessage = 'Invalid or expired code. Please try again.';
        }
        _status = AuthStatus.codeSent;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on http.ClientException catch (e) {
      _errorMessage = 'Network error: ${e.message}. Please check your connection.';
      _status = AuthStatus.codeSent;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      AppLog.error('Auth', 'Authentication failed', error: e, stackTrace: stack, recoverable: true);
      _errorMessage = 'Network error. Please check your connection.';
      _status = AuthStatus.codeSent;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh access token using refresh token
  /// This method attempts to refresh the access token using the stored refresh token.
  /// Returns false if server is unavailable or token is invalid/expired.
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      try {
        // Try to call the refresh endpoint
        final requestBody = jsonEncode({'refresh_token': refreshToken});

        final response = await LoggedHttp.post(
          Uri.parse(ApiConfig.refreshTokenEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Parse the VerifyCodeResponse (same format as verify-code endpoint)
          // Backend always returns: access_token, refresh_token (rotated), token_type
          final responseBody = jsonDecode(response.body);
          final tokens = VerifyCodeResponse.fromJson(responseBody);
          
          // Backend always rotates refresh tokens, so we always get a new one
          _accessToken = tokens.accessToken;
          
          // Store both tokens securely (refresh token is always rotated)
          await _secureStorage.write(key: _tokenKey, value: tokens.accessToken);
          await _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken);
          
          // Update profile completion status if included in response
          // If refresh endpoint returns profile_complete, use it; otherwise keep existing value
          if (tokens.profileComplete != null) {
            _profileComplete = tokens.profileComplete!;
            await _secureStorage.write(key: _profileCompleteKey, value: _profileComplete.toString());
          } else {
            // If not in response, verify with /me endpoint
            try {
              final profileStatus = await _checkProfileCompletionStatus();
              if (profileStatus != null) {
                _profileComplete = profileStatus;
                await _secureStorage.write(key: _profileCompleteKey, value: _profileComplete.toString());
              }
            } catch (e) {
              // Keep existing value if check fails
            }
          }
          
          return true;
        } else if (response.statusCode == 400) {
          AppLog.warning('Auth', 'Authentication expired');
          await _clearAuth();
          return false;
        } else if (response.statusCode == 401) {
          AppLog.warning('Auth', 'Authentication expired');
          await _clearAuth();
          return false;
        } else {
          // Other error - server issue
          return false;
        }
      } on http.ClientException catch (e) {
        // Network error - server is likely unavailable
        return false;
      } on Exception catch (e) {
        // Timeout or other network errors
        return false;
      }
    } catch (e, stack) {
      AppLog.error('Auth', 'Authentication expired', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Get a valid access token, refreshing if necessary
  /// This method ensures you always have a valid access token before making API calls.
  /// It will automatically refresh the token if needed.
  Future<String?> getValidAccessToken() async {
    // If we have an access token in memory, use it
    if (_accessToken != null) {
      return _accessToken;
    }
    
    // Try to get from storage
    final token = await _secureStorage.read(key: _tokenKey);
    if (token != null) {
      _accessToken = token;
      return token;
    }
    
    // No access token, try to refresh (serialized to avoid concurrent refresh race)
    final refreshed = await refreshTokenIfNeeded();
    if (refreshed) {
      _accessToken = await _secureStorage.read(key: _tokenKey);
      return _accessToken;
    }
    
    return null;
  }

  /// Refresh token if needed (public method for manual refresh).
  /// Serializes concurrent refresh calls so only one refresh runs at a time,
  /// avoiding 400 from reusing a rotated refresh token.
  Future<bool> refreshTokenIfNeeded() async {
    if (_refreshInProgress != null) return _refreshInProgress!;
    _refreshInProgress = _refreshToken();
    try {
      return await _refreshInProgress!;
    } finally {
      _refreshInProgress = null;
    }
  }

  /// Clear authentication and log out
  Future<void> logout() async {
    await _clearAuth();
    _status = AuthStatus.unauthenticated;
    _email = null;
    _accessToken = null;
    _errorMessage = null;
    _profileComplete = false;
    AppLog.info('Auth', 'User signed out');
    notifyListeners();
  }

  /// Mark profile as complete
  /// Call this after the user completes their profile
  Future<void> markProfileComplete() async {
    _profileComplete = true;
    try {
      await _secureStorage.write(key: _profileCompleteKey, value: 'true');
      notifyListeners();
    } catch (e) {
    }
  }

  /// Clear stored authentication data
  Future<void> _clearAuth() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _profileCompleteKey);
      _profileComplete = false;
    } catch (e) {
      // If secure storage is unavailable (e.g., MissingPluginException during hot restart),
      // silently ignore - plugin will be available after full rebuild
    }
  }

  /// Reset auth flow (go back to email entry)
  void reset() {
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    // Keep email for convenience
    notifyListeners();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch email from /me endpoint
  /// Returns email if successful, null otherwise
  Future<String?> _fetchEmailFromMe() async {
    if (_accessToken == null) return null;

    try {

      final response = await LoggedHttp.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final email = responseBody['email'] as String?;
        return email?.toLowerCase();
      } else {
        return null;
      }
    } catch (e, stack) {
      AppLog.error('Auth', 'Failed to fetch user profile', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  /// Check profile completion status by calling /me endpoint
  /// Returns true if profile is complete, false if not, null if check failed
  Future<bool?> _checkProfileCompletionStatus() async {
    if (_accessToken == null) return null;

    try {

      final response = await LoggedHttp.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // Prefer backend's profile_complete when present (server/schemas/racer.py)
        final backendComplete = responseBody['profile_complete'];
        if (backendComplete is bool) {
          return backendComplete;
        }
        // Fallback: compute from required fields matching server RacerBase.profile_complete
        final firstName = responseBody['first_name'] as String?;
        final lastName = responseBody['last_name'] as String?;
        final dateOfBirth = responseBody['date_of_birth'];
        final phone = responseBody['phone'] as String?;
        final emergencyContactName = responseBody['emergency_contact_name'] as String?;
        final emergencyContactPhone = responseBody['emergency_contact_phone'] as String?;
        final street = responseBody['street'] as String?;
        final city = responseBody['city'] as String?;
        final stateProvince = responseBody['state_province'] as String?;
        final country = responseBody['country'] as String?;
        final zipPostalCode = responseBody['zip_postal_code'] as String?;

        final isComplete = firstName != null && firstName.isNotEmpty &&
            lastName != null && lastName.isNotEmpty &&
            dateOfBirth != null &&
            phone != null && phone.isNotEmpty &&
            emergencyContactName != null && emergencyContactName.isNotEmpty &&
            emergencyContactPhone != null && emergencyContactPhone.isNotEmpty &&
            street != null && street.isNotEmpty &&
            city != null && city.isNotEmpty &&
            stateProvince != null && stateProvince.isNotEmpty &&
            country != null && country.isNotEmpty &&
            zipPostalCode != null && zipPostalCode.isNotEmpty;

        return isComplete;
      } else {
        return null;
      }
    } catch (e, stack) {
      AppLog.error('Auth', 'Failed to check profile completion', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  /// Retry connection to server
  /// Used when server was unavailable to check again
  Future<void> retryConnection() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Check server health
    final serverAvailable = await _checkServerHealth();
    
    if (serverAvailable) {
      // Server is available, try to check auth again
      _status = AuthStatus.unauthenticated;
      await _checkExistingAuth();
    } else {
      // Still unavailable
      _status = AuthStatus.serverUnavailable;
      _errorMessage = 'Server is still unavailable. Please check your connection.';
      _isLoading = false;
      notifyListeners();
    }
  }
}