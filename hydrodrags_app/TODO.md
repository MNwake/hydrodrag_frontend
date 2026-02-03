# HydroDrags App - TODO List

## 🔴 High Priority

### Engineering/Architecture

#### Event Registration Simplification
- [x] Refactor `event_registration_screen.dart` to use racer profile data
- [x] Remove duplicate data entry (make, model, engine class from PWC)
- [x] Simplify to 3 steps: Class Selection → Waiver → Payment
- [x] Update `EventRegistration` model to remove redundant fields
- [x] Pre-populate from racer's primary PWC
- [x] Add PWC selection dropdown (if multiple PWCs)
- [x] Remove craft type, make, model, engine class input fields

#### Payment Integration
- [ ] Integrate PayPal SDK (`paypal_payment` or `flutter_paypal`)
- [ ] Create payment service (`payment_service.dart`)
- [ ] Add payment step to registration flow
- [ ] Handle payment success/failure states
- [ ] Store payment transaction ID
- [ ] Add payment retry mechanism
- [ ] Implement payment webhook handling (backend integration)

#### Backend Integration
- [ ] Update `racers_list_tab_screen.dart` to fetch from backend API
- [ ] Create `GET /racers` endpoint integration
- [ ] Add pagination for racers list
- [ ] Implement search/filter for racers
- [ ] Add event registration API endpoint integration
- [ ] Create registration submission service method
- [ ] Handle registration API responses

#### Error Handling & Resilience
- [x] Add comprehensive error states to all screens (in progress)
- [x] Create centralized error handling service
- [x] Implement retry logic for failed API calls
- [ ] Add network connectivity checking
- [x] Improve error messages (user-friendly, localized)
- [x] Add error logging/analytics
- [ ] Handle edge cases (empty states, timeouts, etc.)
- [ ] Add offline mode detection and messaging

### UI/UX

#### Event Registration Flow
- [ ] Redesign registration flow with simplified steps
- [ ] Add progress indicator showing 3 steps
- [ ] Improve visual feedback during registration
- [ ] Add confirmation dialogs for critical actions
- [ ] Show registration summary before payment
- [ ] Add "Back" navigation with data preservation

#### Loading & Empty States
- [ ] Standardize loading indicators across all screens
- [ ] Add skeleton loaders for better perceived performance
- [ ] Improve empty state designs (no events, no PWCs, etc.)
- [x] Add pull-to-refresh to all list screens
- [ ] Add loading states for image uploads

#### Form Validation & UX
- [ ] Add inline validation feedback
- [ ] Improve error message placement
- [ ] Add form field auto-save (draft functionality)
- [ ] Add "Are you sure?" dialogs for destructive actions
- [ ] Improve date picker UX
- [ ] Add input field focus management improvements

---

## 🟡 Medium Priority

### Engineering/Architecture

#### State Management
- [ ] Consider migrating to Riverpod for better testability
- [ ] Add state persistence for offline support
- [ ] Implement optimistic UI updates
- [ ] Add state hydration on app startup
- [ ] Reduce AppStateService usage (move to services)
- [ ] Add proper state cleanup on logout

#### Data Caching & Performance
- [ ] Implement image caching for profile pictures
- [ ] Add event data caching with TTL
- [ ] Implement local database (Hive/SQLite) for offline data
- [ ] Add API response caching
- [ ] Optimize list rendering (use ListView.builder properly)
- [ ] Add image compression before upload
- [ ] Implement lazy loading for images

#### Code Quality & Architecture
- [ ] Add dependency injection (get_it or similar)
- [ ] Create repository pattern for data access
- [ ] Separate business logic from UI (BLoC pattern consideration)
- [ ] Add comprehensive unit tests
- [ ] Add widget tests for critical screens
- [ ] Add integration tests for registration flow
- [ ] Implement code generation for models (json_serializable)
- [ ] Add linting rules (custom analysis_options.yaml)
- [ ] Remove hardcoded strings (ensure all localized)

#### API & Network
- [ ] Add request/response interceptors
- [ ] Implement API rate limiting handling
- [ ] Add request cancellation support
- [ ] Implement request queuing for offline mode
- [ ] Add API versioning support
- [ ] Create API response models with proper typing
- [ ] Add request timeout configuration
- [ ] Implement exponential backoff for retries

#### Security
- [ ] Add certificate pinning for production
- [ ] Implement secure token storage verification
- [ ] Add biometric authentication option
- [ ] Implement session timeout
- [ ] Add security headers validation
- [ ] Review and secure all API endpoints

### UI/UX

#### Visual Design
- [ ] Add consistent spacing system (8px grid)
- [ ] Standardize card designs across app
- [ ] Improve color contrast for accessibility
- [ ] Add consistent iconography
- [ ] Improve typography hierarchy
- [ ] Add micro-interactions and animations
- [ ] Implement consistent button styles
- [ ] Add loading shimmer effects

#### Navigation & Flow
- [ ] Add deep linking support
- [ ] Implement proper back navigation handling
- [ ] Add navigation breadcrumbs
- [ ] Improve tab bar UX (add badges, indicators)
- [ ] Add swipe gestures for navigation
- [ ] Implement bottom sheet for quick actions
- [ ] Add floating action button consistency

#### Accessibility
- [ ] Add semantic labels to all interactive elements
- [ ] Improve screen reader support
- [ ] Add high contrast mode support
- [ ] Implement proper focus management
- [ ] Add keyboard navigation support
- [ ] Test with accessibility tools
- [ ] Add font scaling support
- [ ] Ensure minimum touch target sizes (44x44)

#### User Feedback
- [ ] Add success animations/confetti
- [ ] Improve snackbar/toast messaging
- [ ] Add haptic feedback for actions
- [ ] Implement progress indicators for long operations
- [ ] Add confirmation animations
- [ ] Improve error message clarity

#### Profile & Account
- [ ] Add profile image cropping/editing
- [ ] Improve profile image upload UX
- [ ] Add profile completion progress indicator
- [ ] Show profile completeness percentage
- [ ] Add quick edit shortcuts in account screen
- [ ] Improve PWC list card design
- [ ] Add PWC image upload capability

#### Events & Registration
- [ ] Add event filtering (by date, status, location)
- [ ] Implement event search functionality
- [ ] Add event favorites/bookmarks
- [ ] Show event countdown timer
- [ ] Add event calendar integration
- [ ] Improve registered racers list design
- [ ] Add racer profile quick view from events
- [ ] Show registration status badge

---

## 🟢 Low Priority

### Engineering/Architecture

#### Advanced Features
- [ ] Implement push notifications
- [ ] Add analytics integration (Firebase/Mixpanel)
- [ ] Add crash reporting (Sentry)
- [ ] Implement A/B testing framework
- [ ] Add feature flags system
- [ ] Implement app update checking
- [ ] Add in-app messaging/announcements
- [ ] Create admin dashboard (web or separate app)

#### Testing & Quality
- [ ] Achieve 80%+ code coverage
- [ ] Add E2E tests with integration_test
- [ ] Implement visual regression testing
- [ ] Add performance profiling
- [ ] Create test data factories
- [ ] Add mock API server for testing
- [ ] Implement CI/CD pipeline
- [ ] Add automated screenshot testing

#### Documentation
- [ ] Add code documentation (dartdoc)
- [ ] Create architecture decision records (ADRs)
- [ ] Document API contracts
- [ ] Add developer onboarding guide
- [ ] Create troubleshooting guide
- [ ] Document deployment process
- [ ] Add changelog maintenance

#### Performance Optimization
- [ ] Profile app startup time
- [ ] Optimize bundle size
- [ ] Implement code splitting
- [ ] Add performance monitoring
- [ ] Optimize image loading
- [ ] Reduce memory footprint
- [ ] Implement background sync

### UI/UX

#### Enhanced Features
- [ ] Add dark/light theme toggle (currently only dark)
- [ ] Implement custom theme colors
- [ ] Add event results visualization
- [ ] Create racer statistics dashboard
- [ ] Add social sharing capabilities
- [ ] Implement event reminders
- [ ] Add weather integration for events
- [ ] Create event photo gallery

#### Polish & Refinement
- [ ] Add onboarding flow for new users
- [ ] Create help/tutorial screens
- [ ] Add tooltips for complex features
- [ ] Implement contextual help
- [ ] Add "What's New" screen
- [ ] Create feedback mechanism
- [ ] Add rating/review system
- [ ] Implement user preferences screen

#### Internationalization
- [ ] Add more languages (French, Portuguese, etc.)
- [ ] Implement RTL support
- [ ] Add date/time localization
- [ ] Localize currency formatting
- [ ] Add region-specific features

---

## 🔵 Future Considerations

### Engineering
- [ ] Migrate to Flutter 3.x latest
- [ ] Consider Flutter Web support
- [ ] Evaluate desktop app support
- [ ] Implement GraphQL API (if needed)
- [ ] Add real-time features (WebSocket)
- [ ] Consider microservices architecture
- [ ] Implement event sourcing for audit trail

### Features
- [ ] Add live race tracking
- [ ] Implement real-time leaderboards
- [ ] Add social features (follow racers, comments)
- [ ] Create racer comparison tool
- [ ] Add event streaming integration
- [ ] Implement QR code scanning
- [ ] Add NFC support for check-ins
- [ ] Create event management tools

### Business
- [ ] Add subscription/premium features
- [ ] Implement referral program
- [ ] Add sponsorship integration
- [ ] Create merchandise store
- [ ] Add ticket purchasing
- [ ] Implement loyalty program

---

## 📋 Quick Wins (Can be done quickly)

- [x] Add pull-to-refresh to events list ✅
- [x] Add pull-to-refresh to PWC list ✅
- [x] Add pull-to-refresh to racers list ✅
- [x] Standardize error messages ✅
- [x] Add loading states to all API calls (in progress)
- [ ] Improve empty state messages
- [x] Add confirmation dialogs for delete actions ✅ (PWC delete has confirmation)
- [x] Fix hardcoded strings in waiver screens ✅
- [x] Fix hardcoded strings in registration screens ✅
- [ ] Add image placeholder for missing profile images
- [ ] Improve button disabled states
- [ ] Add form validation visual feedback
- [ ] Standardize spacing in cards

---

## 🐛 Bug Fixes Needed

- [x] Fix waiver ID hardcoding in `waiver_signature_screen.dart` ✅
- [x] Fix registration details TODO in `registration_complete_screen.dart` ✅ (added placeholder with message)
- [x] Fix PDF download TODO in `waiver_overview_screen.dart` ✅ (added placeholder with message)
- [ ] Ensure all screens handle null states properly
- [ ] Fix potential memory leaks in controllers
- [ ] Verify all dispose methods are called
- [ ] Check for unhandled exceptions

---

## 📝 Notes

- Prioritize items based on user feedback and business needs
- Review and update this list quarterly
- Mark items as complete with ✅ when done
- Add new items as they are discovered
- Break down large items into smaller tasks

---

**Last Updated**: 2024-12-19
**Total Items**: ~150+ improvements identified
