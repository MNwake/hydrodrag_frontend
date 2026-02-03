# HydroDrags App - Comprehensive Audit & Documentation

## App Overview
HydroDrags is a Flutter mobile application for managing PWC (Personal Watercraft) drag racing events, racer registrations, and profiles.

## Architecture

### State Management
- **Provider**: Used for global state management
- **Services**: 
  - `AuthService`: Authentication, token management, profile completion status
  - `AppStateService`: Temporary app state (selected event, registration data, waiver)
  - `LanguageService`: Language preference management
  - `RacerService`: Racer profile CRUD operations
  - `PWCService`: Personal Watercraft management
  - `EventService`: Event data and registered racers

### Navigation Flow

```
Login Screen
  ↓ (authenticated)
  ↓ (profile incomplete)
Racer Profile Screen (multi-step form)
  ↓ (profile complete)
Main Navigation Screen
  ├── Info Tab (About/Rules/Sponsors)
  ├── Events Tab (Event list)
  │     └── Event Detail Screen
  │           ├── Registered Racers Section
  │           └── Register Button → Event Registration
  ├── Racers List Tab (All racers)
  │     └── Racer Profile Detail Screen
  └── Account Management Tab
        ├── Basic Info (quick edit)
        ├── Edit Full Profile
        ├── PWC Management
        │     ├── PWC List
        │     └── PWC Edit Screen
        └── Sign Out

Event Registration Flow:
  Event Detail → Event Registration Screen
    ↓ (select class/division, PWC)
    ↓ (waiver)
    ↓ (payment via PayPal)
  Registration Complete
```

## Screens Inventory

### Active Screens
1. **login_screen.dart** - Email/code authentication
2. **main_navigation_screen.dart** - Bottom tab navigation container
3. **info_tab_screen.dart** - About/Rules/Sponsors information
4. **events_tab_screen.dart** - Events list (used in main navigation)
5. **event_detail_screen.dart** - Event details with registered racers
6. **event_registration_screen.dart** - Registration flow (needs simplification)
7. **racers_list_tab_screen.dart** - List of all racers
8. **racer_profile_detail_screen.dart** - Individual racer profile view
9. **racer_profile_screen.dart** - Multi-step profile creation/editing
10. **account_management_tab_screen.dart** - Account management with PWC access
11. **pwc_management_screen.dart** - PWC list and management
12. **pwc_edit_screen.dart** - PWC create/edit form
13. **waiver_overview_screen.dart** - Waiver overview
14. **waiver_reading_screen.dart** - Waiver reading
15. **waiver_signature_screen.dart** - Waiver signing
16. **registration_complete_screen.dart** - Registration confirmation
17. **racer_dashboard_screen.dart** - Racer's event dashboard
18. **server_unavailable_screen.dart** - Server error handling

### Removed Screens (CLEANED UP)
1. ✅ **auth_screen.dart** - Removed (replaced by login_screen.dart)
2. ✅ **welcome_screen.dart** - Removed (not used in current flow)
3. ✅ **splash_screen.dart** - Removed (not used)
4. ✅ **admin_screen.dart** - Removed (not implemented)
5. ✅ **events_screen.dart** - Removed (duplicate, consolidated into events_tab_screen.dart)

### Removed Widgets (CLEANED UP)
1. ✅ **form_card.dart** - Removed (not used anywhere)

## Data Models

### Core Models
- **RacerProfile**: Personal info, contact, address, membership
- **PWC**: Personal watercraft with make, model, engine, modifications
- **Event**: Comprehensive event data with location, schedule, info
- **EventRegistration**: Registration data (needs simplification)
- **RegisteredRacer**: Racer registration for events
- **WaiverSignature**: Waiver signing data

## Backend API Integration

### Endpoints Used
- `POST /auth/request-code` - Request verification code
- `POST /auth/verify-code` - Verify code and get tokens
- `POST /auth/refresh` - Refresh access token
- `GET /health` - Server health check
- `GET /me` - Get current racer profile
- `PATCH /racers/{racer_id}` - Update racer profile
- `POST /me/profile-image` - Upload profile image
- `GET /me/pwcs` - Get racer's PWCs
- `POST /me/pwcs` - Create PWC
- `PATCH /me/pwcs/{pwc_id}` - Update PWC
- `DELETE /me/pwcs/{pwc_id}` - Delete PWC
- `PATCH /me/pwcs/{pwc_id}/set-primary` - Set primary PWC
- `GET /events` - Get all events
- `GET /events/{event_id}` - Get event details
- `GET /events/{event_id}/registrations` - Get registered racers

## Localization
- **Languages**: English (en), Spanish (es)
- **Files**: `app_en.arb`, `app_es.arb`
- **Coverage**: All user-facing strings localized

## Known Issues & TODOs

### High Priority
1. **Event Registration Simplification**: 
   - Should use racer profile data (no need to re-enter)
   - Should use PWC data from account
   - Only need: class/division selection, waiver, payment
   - Current flow is too complex

2. **Events Data**: 
   - `events_tab_screen.dart` uses mock data
   - Should fetch from `EventService.getEvents()`

3. **Payment Integration**: 
   - PayPal integration not yet implemented
   - Need to add payment step to registration flow

### Medium Priority
1. **Racers List**: Uses mock data, should fetch from backend
2. **Event Registration Model**: Needs simplification to match new flow
3. **Error Handling**: Some screens lack proper error states

### Low Priority
1. **Admin Features**: Not yet implemented
2. **Results Display**: Placeholder only
3. **Image Caching**: Profile images not cached

## Cleanup Actions Completed

1. ✅ Removed unused screens: auth_screen, welcome_screen, splash_screen, admin_screen
2. ✅ Removed unused widget: form_card.dart
3. ✅ Consolidated events screens (removed events_screen.dart, updated events_tab_screen to use backend)
4. ✅ Updated events_tab_screen to fetch from EventService
5. ✅ Removed unused /events route from main.dart
6. ✅ Updated navigation in racer_dashboard_screen to use main navigation

## Remaining Tasks

1. ⏳ **Simplify Event Registration**: 
   - Remove duplicate data entry (use profile/PWC from account)
   - Only collect: class/division, waiver, payment
   - Update EventRegistration model accordingly

2. ⏳ **PayPal Payment Integration**: 
   - Add payment step to registration flow
   - Integrate PayPal SDK
   - Handle payment success/failure

3. ⏳ **Racers List Backend Integration**: 
   - Update racers_list_tab_screen to fetch from backend
   - Add API endpoint for racers list

4. ⏳ **Error Handling**: 
   - Add comprehensive error states to all screens
   - Improve user feedback for API errors

## Testing Checklist

- [ ] Login flow (email/code)
- [ ] Profile creation (all steps)
- [ ] Profile editing
- [ ] PWC management (CRUD)
- [ ] Event browsing
- [ ] Event registration (simplified flow)
- [ ] Waiver signing
- [ ] Payment processing
- [ ] Language switching
- [ ] Server unavailable handling
- [ ] Token refresh
- [ ] Profile completion check

## File Structure

```
lib/
├── config/          # API configuration
├── l10n/            # Localization files
├── models/          # Data models
├── screens/         # UI screens
├── services/        # Business logic & API
├── theme/           # App theming
├── utils/           # Utilities
└── widgets/         # Reusable widgets
```

## Dependencies

Key packages:
- `provider` - State management
- `http` - API calls
- `flutter_secure_storage` - Secure token storage
- `image_picker` - Profile image selection
- `path_provider` - File system access
- `intl` - Localization
