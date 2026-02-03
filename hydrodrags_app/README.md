# HydroDrags Mobile App

A Flutter mobile application for managing PWC (Personal Watercraft) drag racing events, racer registrations, and profiles.

## Features

### Authentication & Profile
- **Email/Code Authentication**: Passwordless login via email verification code
- **Persistent Login**: Automatic token refresh for seamless user experience
- **Profile Management**: Complete racer profile with personal info, contact details, address, and membership
- **Profile Image Upload**: Upload and manage profile pictures
- **Multi-language Support**: English and Spanish localization

### Personal Watercraft (PWC) Management
- **PWC CRUD Operations**: Create, read, update, and delete personal watercraft
- **PWC Details**: Track make, model, year, engine class, modifications, and more
- **Primary PWC**: Set a default PWC for race registrations
- **Comprehensive Data**: Store registration numbers, serial numbers, and custom notes

### Events
- **Event Browsing**: View all upcoming events with details
- **Event Details**: Comprehensive event information including:
  - Location and venue details
  - Date and time
  - Race schedule
  - Event information (parking, tickets, food & drink, seating)
  - Registered racers list
- **Event Registration**: Simplified registration flow using profile and PWC data

### Registration Flow
1. **Class/Division Selection**: Choose racing class
2. **PWC Selection**: Select from registered PWCs
3. **Waiver**: Review and sign liability waiver
4. **Payment**: PayPal integration (to be implemented)

### Other Features
- **Racers Directory**: Browse all registered racers
- **Account Management**: Quick access to profile editing and PWC management
- **Server Health Monitoring**: Graceful handling of server unavailability
- **Offline Support**: Token-based authentication works offline

## Architecture

### State Management
- **Provider**: Global state management
- **Services**: Business logic and API integration
  - `AuthService`: Authentication and token management
  - `RacerService`: Profile operations
  - `PWCService`: PWC management
  - `EventService`: Event data and registrations
  - `AppStateService`: Temporary app state
  - `LanguageService`: Language preferences

### Navigation
- **Bottom Tab Navigation**: Main app navigation with 4 tabs
  - Info (About/Rules/Sponsors)
  - Events
  - Racers List
  - Account Management
- **Route-based Navigation**: For registration flow and detail screens

## Project Structure

```
lib/
├── config/          # API configuration
├── l10n/            # Localization files (English & Spanish)
├── models/          # Data models
│   ├── event.dart
│   ├── pwc.dart
│   ├── racer_profile.dart
│   ├── registered_racer.dart
│   └── ...
├── screens/         # UI screens
│   ├── login_screen.dart
│   ├── main_navigation_screen.dart
│   ├── racer_profile_screen.dart
│   ├── pwc_management_screen.dart
│   ├── event_detail_screen.dart
│   └── ...
├── services/        # Business logic & API
│   ├── auth_service.dart
│   ├── racer_service.dart
│   ├── pwc_service.dart
│   ├── event_service.dart
│   └── ...
├── theme/           # App theming
├── utils/           # Utilities (phone formatting, etc.)
└── widgets/         # Reusable widgets
```

## Setup

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- iOS: Xcode (for iOS builds)
- Android: Android Studio (for Android builds)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate localization files:
   ```bash
   flutter gen-l10n
   ```

4. Configure API endpoint in `lib/config/api_config.dart`

5. Run the app:
   ```bash
   flutter run
   ```

## Configuration

### API Configuration
Update `lib/config/api_config.dart` with your backend API URL:
```dart
static const String baseUrl = 'http://your-api-url:8000';
```

### Environment Variables
For production, use `--dart-define` to set API URLs:
```bash
flutter run --dart-define=API_URL=https://api.hydrodrags.com
```

## Backend API Requirements

The app expects the following backend endpoints:

### Authentication
- `POST /auth/request-code` - Request verification code
- `POST /auth/verify-code` - Verify code and get tokens
- `POST /auth/refresh` - Refresh access token
- `GET /health` - Server health check

### Profile
- `GET /me` - Get current racer profile
- `PATCH /racers/{racer_id}` - Update racer profile
- `POST /me/profile-image` - Upload profile image

### PWC Management
- `GET /me/pwcs` - Get racer's PWCs
- `POST /me/pwcs` - Create PWC
- `PATCH /me/pwcs/{pwc_id}` - Update PWC
- `DELETE /me/pwcs/{pwc_id}` - Delete PWC
- `PATCH /me/pwcs/{pwc_id}/set-primary` - Set primary PWC

### Events
- `GET /events` - Get all events
- `GET /events/{event_id}` - Get event details
- `GET /events/{event_id}/registrations` - Get registered racers

See `lib/services/AUTH_BACKEND_MATCH.md` for detailed API specifications.

## Localization

The app supports English and Spanish. All user-facing strings are localized in:
- `lib/l10n/app_en.arb` (English)
- `lib/l10n/app_es.arb` (Spanish)

To add new strings:
1. Add the key-value pair to both `.arb` files
2. Run `flutter gen-l10n` to regenerate localization classes
3. Use `AppLocalizations.of(context)!.yourKey` in code

## Testing

### Manual Testing Checklist
- [ ] Login flow (email/code verification)
- [ ] Profile creation (all 4 steps)
- [ ] Profile editing
- [ ] PWC management (create, edit, delete, set primary)
- [ ] Event browsing
- [ ] Event detail view
- [ ] Event registration flow
- [ ] Waiver signing
- [ ] Language switching
- [ ] Server unavailable handling
- [ ] Token refresh
- [ ] Profile completion check

## Known Issues & TODOs

### High Priority
- [ ] Simplify event registration to use profile/PWC data
- [ ] Implement PayPal payment integration
- [ ] Add error handling for all API calls
- [ ] Implement racers list backend integration

### Medium Priority
- [ ] Add image caching for profile pictures
- [ ] Implement event results display
- [ ] Add search/filter for events and racers
- [ ] Add pull-to-refresh on all list screens

### Low Priority
- [ ] Admin features
- [ ] Push notifications
- [ ] Offline data caching
- [ ] Analytics integration

## Contributing

1. Follow Flutter/Dart style guidelines
2. Ensure all new strings are localized
3. Add appropriate error handling
4. Test on both iOS and Android
5. Update documentation as needed

## License

[Your License Here]

## Support

For issues or questions, please contact [support email] or open an issue in the repository.
