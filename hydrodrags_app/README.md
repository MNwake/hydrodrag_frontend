# HydroDrags

A Flutter mobile app for **HydroDrags** PWC (Personal Watercraft) drag racing: events, racer profiles, class-based registration, and live results. Built for iOS and Android with English and Spanish support.

## Overview

HydroDrags connects racers and spectators to jet ski drag events. Racers manage their profile and watercraft, register for events by class, sign waivers, and pay via PayPal. Spectators can browse events and purchase admission without an account. The app shows live results—bracket progression for elimination events and top-speed rankings with a session timer for speed-format events.

## Features

### For Racers
- **Passwordless auth** — Email verification code; persistent sessions with token refresh
- **Profile & PWC** — Full racer profile (contact, address, membership), profile photo, and CRUD for personal watercraft (make, model, class, primary PWC)
- **Events** — Browse events, view details (schedule, venue, info, registered racers), and register by class with waiver and PayPal checkout
- **My registrations & tickets** — View registrations and digital tickets with QR codes

### For Spectators
- **No login required** — Purchase spectator tickets with name, phone, and email; receive tickets with QR codes and confirmation by email

### Results
- **Bracket events** — Double-elimination bracket view with rounds and matchups
- **Top-speed events** — Session timer (remaining time / ended / not started) and live rankings (place, racer name, speed in mph) with pull-to-refresh

### General
- **English & Spanish** — Full localization (l10n)
- **Resilience** — Graceful handling of server unavailability; token-based auth for offline-capable flows

## Tech Stack

- **Flutter** (Dart) — Cross-platform UI
- **Provider** — App-wide state
- **REST API** — Backend for auth, profile, events, registrations, PayPal, and speed sessions

## Project Structure

```
lib/
├── config/          # API base URL and endpoints
├── l10n/            # Localization (app_en.arb, app_es.arb)
├── models/          # Domain models (event, racer, PWC, registration, speed session, etc.)
├── screens/         # Full-screen UIs (login, main tabs, event detail, checkout, results, …)
├── services/        # API and business logic (auth, racer, PWC, event, checkout, config)
├── theme/           # Material theme and styling
├── utils/           # Helpers (e.g. phone formatting)
└── widgets/         # Reusable components (bracket column, etc.)
```

## Setup

### Prerequisites
- Flutter SDK (stable)
- Xcode (iOS) or Android Studio / SDK (Android)

### Run locally

```bash
cd hydrodrags_app
flutter pub get
flutter gen-l10n
flutter run
```

### API configuration

The app reads the backend URL from the environment. Default is the hosted API; override for local development:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
```

Set `API_BASE_URL` in `lib/config/api_config.dart` or via `--dart-define` for production builds.

## Backend

The app expects a REST API for auth, profile, PWC, events, registrations, PayPal checkout (racer and spectator), and speed sessions. Example surface:

- **Auth:** `POST /auth/request-code`, `POST /auth/verify-code`, `POST /auth/refresh`, `GET /health`
- **Profile:** `GET /me`, `PATCH /racers/{id}`, `POST /me/profile-image`
- **PWC:** `GET|POST /me/pwc`, `PATCH|DELETE /me/pwcs/{id}`, `PATCH .../set-primary`
- **Events:** `GET /events`, `GET /events/{id}`, `GET /registrations/event/{id}/registrations`
- **Checkout:** `POST /paypal/events/{id}/checkout/create`, `.../capture`; `POST /paypal/spectator-checkout/create`, `.../capture`
- **Results:** `GET /speed/session?event_id=&class_key=` (for top-speed events); bracket data as used by the Results tab

See service files and `lib/config/api_config.dart` for full endpoint usage.

## Localization

Strings live in `lib/l10n/app_en.arb` and `lib/l10n/app_es.arb`. After editing:

```bash
flutter gen-l10n
```

Use `AppLocalizations.of(context)!.keyName` in the app.

## License

Proprietary. All rights reserved.

---

Part of my portfolio. For questions or collaboration, reach out via the contact details in my profile.
