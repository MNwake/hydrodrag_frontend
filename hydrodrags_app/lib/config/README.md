# API Configuration

## Setting the Backend URL

The API base URL can be configured in several ways:

### 1. Environment Variable (Recommended for Development)
When running the app, you can set the API URL using an environment variable:

```bash
# For local development
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# For network development (replace with your IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000

# For production
flutter run --dart-define=API_BASE_URL=https://api.hydrodrags.com
```

### 2. Default Value
If no environment variable is set, the default is `http://localhost:8000`.

### 3. Direct Code Modification
You can also directly modify `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://your-backend-url:8000';
```

## Backend Endpoints

The app expects the following endpoints:

- `POST /auth/request-code` - Request verification code
  - Request: `{"email": "user@example.com"}`
  - Response: `{"status": "sent"}`

- `POST /auth/verify-code` - Verify code and get tokens
  - Request: `{"email": "user@example.com", "code": "123456"}`
  - Response: `{"access_token": "...", "refresh_token": "...", "token_type": "bearer"}`

- `POST /auth/refresh` - Refresh access token (optional but recommended for persistent login)
  - Request: `{"refresh_token": "..."}`
  - Response: `{"access_token": "...", "refresh_token": "..."}` (refresh_token is optional if token rotation is not used)
  - Note: If this endpoint is not implemented, the app will still work but users will need to re-authenticate when the access token expires

## Testing with Local Backend

1. Start your FastAPI backend server
2. Run the Flutter app with:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://localhost:8000
   ```

## Testing with Network Backend

1. Find your computer's IP address
2. Make sure your backend is accessible on the network
3. Run the Flutter app with:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
   ```

## CORS Configuration (for Web)

If testing on web, make sure your FastAPI backend has CORS enabled:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```
