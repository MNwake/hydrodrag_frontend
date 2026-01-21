# Auth Service - Backend Compatibility

This document confirms that the Flutter AuthService matches the FastAPI backend implementation.

## Endpoint Mapping

### 1. Request Code: `POST /auth/request-code`

**Backend:**
```python
@router.post("/request-code")
async def request_code(payload: AuthRequest, ...):
    # payload: {"email": "user@example.com"}
    return {"status": "sent"}
```

**Flutter:**
```dart
// Request body matches
jsonEncode({'email': email})
// Response parsing matches
responseBody['status'] == 'sent'
```

✅ **Matches**

---

### 2. Verify Code: `POST /auth/verify-code`

**Backend:**
```python
@router.post("/verify-code", response_model=VerifyCodeResponse)
async def verify_code(payload: VerifyCodeRequest, ...):
    # payload: {"email": "...", "code": "..."}
    # Returns: {"access_token": "...", "refresh_token": "...", "token_type": "bearer"}
```

**Flutter:**
```dart
// Request body matches
jsonEncode({
  'email': _email,
  'code': code,
})
// Response parsing matches VerifyCodeResponse model
VerifyCodeResponse.fromJson(responseBody)
// Fields: access_token, refresh_token, token_type
```

✅ **Matches**

---

### 3. Refresh Token: `POST /auth/refresh`

**Backend:**
```python
@router.post("/refresh", response_model=VerifyCodeResponse)
async def refresh_token(payload: RefreshTokenRequest, ...):
    # payload: {"refresh_token": "..."}
    # Returns: {"access_token": "...", "refresh_token": "...", "token_type": "bearer"}
    # Note: Always rotates refresh token (returns new one)
```

**Flutter:**
```dart
// Request body matches RefreshTokenRequest
jsonEncode({'refresh_token': refreshToken})
// Response parsing matches VerifyCodeResponse
VerifyCodeResponse.fromJson(responseBody)
// Always stores new refresh_token (token rotation)
await _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken);
```

✅ **Matches**

---

## Error Handling

### Backend Error Responses

**Backend raises `ValueError` which FastAPI converts to HTTP 400:**
```python
raise ValueError("Invalid or expired refresh token")
# FastAPI returns: HTTP 400 with {"detail": "Invalid or expired refresh token"}
```

**Flutter handles:**
- ✅ HTTP 400: Clears auth (refresh token invalid/expired)
- ✅ HTTP 401: Clears auth (for consistency)
- ✅ Other errors: Logs but doesn't clear auth (temporary issues)

✅ **Matches**

---

## Token Storage

**Backend:**
- Access token: JWT, expires in 15 minutes (configurable)
- Refresh token: Random token, expires in 30 days
- Refresh token is always rotated on refresh

**Flutter:**
- ✅ Stores both tokens securely using `flutter_secure_storage`
- ✅ Always updates refresh token on refresh (token rotation)
- ✅ Automatically refreshes on app startup

✅ **Matches**

---

## Token Rotation

**Backend:**
```python
# Always rotates refresh token
new_refresh = await self._auth_repo.rotate_refresh_token(stored)
return {
    "access_token": access_token,
    "refresh_token": new_refresh.token,  # Always new token
    "token_type": "bearer",
}
```

**Flutter:**
```dart
// Always expects and stores new refresh_token
await _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken);
```

✅ **Matches**

---

## Summary

All endpoints, request/response formats, error handling, and token management match the backend implementation. The Flutter app is fully compatible with the FastAPI backend.
