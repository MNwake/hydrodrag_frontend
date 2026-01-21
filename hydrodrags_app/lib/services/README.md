# AuthService - Persistent Login with Refresh Tokens

## Overview

The `AuthService` now supports persistent login through refresh tokens. Users can log in once and stay logged in indefinitely, as long as the refresh token is valid.

## How It Works

1. **Initial Login**: When a user verifies their code, they receive both an `access_token` and a `refresh_token`
2. **Token Storage**: Both tokens are stored securely using `flutter_secure_storage`
3. **Automatic Refresh**: On app launch, the service automatically attempts to refresh the access token using the refresh token
4. **Seamless Experience**: Users remain logged in across app restarts without needing to re-authenticate

## Features

- ✅ Automatic token refresh on app startup
- ✅ Secure token storage
- ✅ Fallback support if refresh endpoint is not available
- ✅ Token rotation support (if backend provides new refresh token)
- ✅ Error handling for expired/invalid refresh tokens

## Using Authenticated API Calls

When making authenticated API calls, use `getValidAccessToken()` to ensure you have a valid token:

```dart
final authService = Provider.of<AuthService>(context, listen: false);
final token = await authService.getValidAccessToken();

if (token != null) {
  final response = await http.get(
    Uri.parse('$baseUrl/api/protected-endpoint'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );
  // Handle response...
} else {
  // User is not authenticated
}
```

## Manual Token Refresh

If you need to manually refresh the token:

```dart
final authService = Provider.of<AuthService>(context, listen: false);
final refreshed = await authService.refreshTokenIfNeeded();
```

## Backend Requirements

### Required Endpoint

- `POST /auth/refresh` - Refresh access token
  - Request body: `{"refresh_token": "..."}`
  - Response: `{"access_token": "...", "refresh_token": "..."}`

### Optional Features

- **Token Rotation**: If your backend returns a new `refresh_token` in the refresh response, the app will automatically update it
- **Token Expiration**: The app handles expired refresh tokens by clearing authentication and requiring re-login

## Implementation Notes

- If the refresh endpoint returns a 401 (Unauthorized), the app will clear stored tokens and require re-authentication
- If the refresh endpoint is not available, the app will fall back to using the existing access token (for backwards compatibility)
- Network errors during refresh won't clear authentication - the existing token will be used if available
