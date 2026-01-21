import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Authentication state
enum AuthStatus {
  unauthenticated,
  authenticated,
  codeSent,
  verifying,
}

/// Response model for verify code endpoint
class VerifyCodeResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  VerifyCodeResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory VerifyCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifyCodeResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

/// AuthService manages passwordless email authentication
class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _emailKey = 'user_email';
  
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _email;
  String? _accessToken;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  String? get email => _email;
  String? get accessToken => _accessToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthService() {
    _checkExistingAuth();
  }

  /// Check for existing authentication on app launch
  Future<void> _checkExistingAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _secureStorage.read(key: _tokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final storedEmail = await _secureStorage.read(key: _emailKey);

      if (refreshToken != null && storedEmail != null) {
        // Always try to refresh on app start to get a fresh access token
        // This ensures the user stays logged in indefinitely
        final refreshed = await _refreshToken();
        if (refreshed) {
          _email = storedEmail;
          // Get the updated access token
          _accessToken = await _secureStorage.read(key: _tokenKey);
          _status = AuthStatus.authenticated;
          _errorMessage = null;
        } else {
          // Refresh failed, but if we have a token, try to use it
          // (might be valid but refresh endpoint not available)
          if (token != null) {
            _email = storedEmail;
            _accessToken = token;
            _status = AuthStatus.authenticated;
            _errorMessage = null;
          } else {
            // No valid tokens, clear storage
            await _clearAuth();
          }
        }
      } else if (token != null && storedEmail != null) {
        // Fallback: if we have an access token but no refresh token, use it
        // (for backwards compatibility)
        _email = storedEmail;
        _accessToken = token;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        // No stored credentials
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      // No existing auth or error reading storage (e.g., MissingPluginException during hot restart)
      // Silently handle - plugin will be available after full rebuild
      _status = AuthStatus.unauthenticated;
      try {
        await _clearAuth();
      } catch (_) {
        // Ignore errors when clearing auth (plugin may not be available yet)
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request verification code for email
  Future<bool> requestVerificationCode(String email) async {
    if (!_isValidEmail(email)) {
      _errorMessage = 'Invalid email format';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _email = email;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.requestCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
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
    } on http.ClientException catch (e) {
      _errorMessage = 'Network error: ${e.message}. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting verification code: $e');
      }
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
      final response = await http.post(
        Uri.parse(ApiConfig.verifyCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        // Parse the VerifyCodeResponse
        final responseBody = jsonDecode(response.body);
        final tokens = VerifyCodeResponse.fromJson(responseBody);
        
        _accessToken = tokens.accessToken;
        final refreshToken = tokens.refreshToken;

        // Store tokens securely
        try {
          await _secureStorage.write(key: _tokenKey, value: _accessToken);
          await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
          await _secureStorage.write(key: _emailKey, value: _email);
          
          if (kDebugMode) {
            print('Tokens stored successfully. User will stay logged in.');
          }
        } catch (e) {
          // If secure storage is unavailable (e.g., MissingPluginException), continue anyway
          // Token will be stored in memory only until full rebuild
          if (kDebugMode) {
            print('Warning: Could not store token securely: $e');
          }
        }

        _status = AuthStatus.authenticated;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
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
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying code: $e');
      }
      _errorMessage = 'Network error. Please check your connection.';
      _status = AuthStatus.codeSent;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh access token using refresh token
  /// This method attempts to refresh the access token using the stored refresh token.
  /// If the backend doesn't have a refresh endpoint, it will fall back to checking
  /// if tokens exist (for backwards compatibility).
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      try {
        // Try to call the refresh endpoint
        final response = await http.post(
          Uri.parse(ApiConfig.refreshTokenEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );

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
          
          if (kDebugMode) {
            print('Token refreshed successfully. Refresh token rotated and stored.');
          }
          
          return true;
        } else if (response.statusCode == 400) {
          // Backend returns 400 for ValueError ("Invalid or expired refresh token")
          if (kDebugMode) {
            try {
              final errorBody = jsonDecode(response.body);
              print('Refresh token expired or invalid: ${errorBody['detail'] ?? 'Unknown error'}');
            } catch (_) {
              print('Refresh token expired or invalid (400 Bad Request)');
            }
          }
          // Clear authentication - refresh token is invalid/expired
          await _clearAuth();
          return false;
        } else if (response.statusCode == 401) {
          // Handle 401 for consistency (though backend uses 400)
          if (kDebugMode) {
            print('Refresh token unauthorized (401)');
          }
          await _clearAuth();
          return false;
        } else {
          // Other error - log but don't clear auth (might be temporary server issue)
          if (kDebugMode) {
            print('Refresh token request failed: ${response.statusCode}');
            try {
              final errorBody = jsonDecode(response.body);
              print('Error details: ${errorBody['detail'] ?? errorBody}');
            } catch (_) {
              print('Response body: ${response.body}');
            }
          }
          return false;
        }
      } on http.ClientException catch (e) {
        // Network error - don't clear auth, just return false
        // The existing token might still be valid
        if (kDebugMode) {
          print('Network error refreshing token: ${e.message}');
        }
        // Fall through to check if we have a valid token
      } catch (e) {
        // Other error (e.g., JSON parsing)
        if (kDebugMode) {
          print('Error refreshing token: $e');
        }
        // Fall through to check if we have a valid token
      }
      
      // Fallback: If refresh endpoint doesn't exist or failed, check if we have a token
      // This allows the app to work even if the backend doesn't implement refresh yet
      final token = await _secureStorage.read(key: _tokenKey);
      return token != null;
    } catch (e) {
      // Handle MissingPluginException gracefully during hot restart
      if (kDebugMode) {
        print('Error in refresh token flow: $e');
      }
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
    
    // No access token, try to refresh
    final refreshed = await _refreshToken();
    if (refreshed) {
      _accessToken = await _secureStorage.read(key: _tokenKey);
      return _accessToken;
    }
    
    return null;
  }

  /// Refresh token if needed (public method for manual refresh)
  Future<bool> refreshTokenIfNeeded() async {
    return await _refreshToken();
  }

  /// Clear authentication and log out
  Future<void> logout() async {
    await _clearAuth();
    _status = AuthStatus.unauthenticated;
    _email = null;
    _accessToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear stored authentication data
  Future<void> _clearAuth() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _emailKey);
    } catch (e) {
      // If secure storage is unavailable (e.g., MissingPluginException during hot restart),
      // silently ignore - plugin will be available after full rebuild
      if (kDebugMode) {
        print('Warning: Could not clear secure storage: $e');
      }
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
}