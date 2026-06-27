# HydroDrags Mobile Logging

All application logging flows through [`app_log.dart`](app_log.dart). Do not use `print`, `debugPrint`, or `developer.log` elsewhere in `lib/`.

## API

```dart
AppLog.debug('Category', 'Message');   // Development only — no-op in release
AppLog.info('Category', 'Message');    // Important business events
AppLog.warning('Category', 'Message'); // Recovered unexpected situations
AppLog.error('Category', 'Message',   // Failures
  error: e,
  stackTrace: stack,
  recoverable: true,
);
AppLog.api('GET', '/mobile/events', 200, durationMs: 184); // Debug-only HTTP summary
AppLog.httpFailure('fetch events', 500); // Helper for concise HTTP errors
```

Output format:

```
2026-06-25T12:00:00.000Z [INFO] Auth: User signed in
```

Logs are emitted via `dart:developer` with name `HydroDrags` for logcat filtering.

In **debug builds**, INFO, WARNING, and ERROR also appear in the `flutter run` terminal using a compact format (`[INFO] Auth: User signed in`). DEBUG lines stay DevTools-only unless `terminal: true` is passed (used sparingly, e.g. startup API host).

Each HTTP request logs one line in the terminal via [`logged_http.dart`](logged_http.dart):

```
[API] GET /events -> 200 (184 ms)
```

## Log levels

### DEBUG

Development-only. Disabled in release builds.

Use for navigation flow, state transitions, cache hits, API timing summaries, and WebSocket connect/disconnect.

```dart
AppLog.debug('ImageCache', 'Cache hit');
AppLog.api('GET', '/mobile/events', 200, durationMs: 184);
```

### INFO

Important application events. Always logged in release.

```dart
AppLog.info('Auth', 'User signed in');
AppLog.info('Registration', 'Registration completed');
AppLog.info('MobilePayment', 'Payment approved');
AppLog.info('Waiver', 'Waiver completed');
```

Do not log every screen load, button press, or API request start.

### WARNING

Unexpected situations the app recovered from.

```dart
AppLog.warning('WebSocket', 'Reconnecting (attempt 2, 2s delay)');
AppLog.warning('PaymentRecovery', 'Pending checkout expired');
AppLog.warning('Waiver', 'Session resumed');
```

### ERROR

Genuine failures. Include subsystem, what failed, and whether the user can retry. Stack traces are included in **debug builds only**.

```dart
AppLog.error(
  'EventService',
  'Failed to fetch events',
  error: e,
  stackTrace: stack,
  recoverable: true,
);
```

Future crash reporting / analytics should hook into `AppLog.error`.

## Never log

Do not log personally identifiable or sensitive data:

- Authorization headers, JWT tokens, refresh tokens, session IDs
- Passwords, verification codes (OTP)
- Email addresses, phone numbers
- Driver's license information, government ID images, selfie paths, signature paths
- Payment IDs, PayPal tokens, QR code values
- Device identifiers, GPS coordinates
- Complete JSON request/response bodies

## Good vs bad examples

### Network

```dart
// Good (debug only)
AppLog.api('GET', '/mobile/events', 200, durationMs: 184);

// Bad
print('Response Body: ${response.body}');
```

### Errors

```dart
// Good
AppLog.error('Checkout', 'Payment failed. HTTP 500', recoverable: true);

// Bad
print('Exception');
print(stack);
```

### Business events

```dart
// Good
AppLog.info('MobilePayment', 'Payment cancelled');

// Bad
debugPrint('payment success!!');
```

## Release behavior

| Level   | Release |
|---------|---------|
| DEBUG   | Suppressed |
| INFO    | Logged |
| WARNING | Logged |
| ERROR   | Logged (no stack trace) |

## UI errors

Screen-level errors may use `ErrorHandlerService.logError(...)`, which delegates to `AppLog.error`.

## PayPal SDK

The vendored PayPal plugin has its own internal logger, gated by `debugMode: kDebugMode` in `PayPalCheckoutLauncher`. It is separate from `AppLog`.
