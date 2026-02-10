# HydroDrags Admin Portal

Standalone SvelteKit (TypeScript) web app for event administration. It is **fully separate** from the Flutter mobile app and shares only the backend API.

- **Backend:** FastAPI at `http://192.168.4.231:8000` (configurable)
- **Admin portal:** Runs locally at `http://localhost:5173`

## Quick start

```bash
cd admin_portal
cp .env.example .env.local   # optional; defaults in .env.example
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173). You’ll be redirected to `/login` if not authenticated.

## Environment variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_API_BASE_URL` | Backend API base URL (no trailing slash) | `http://192.168.4.231:8000` |
| `VITE_ADMIN_USERNAME` | Admin login username | `admin` |
| `VITE_ADMIN_PASSWORD` | Admin login password | `Hydr0drags` |

All API requests use `VITE_API_BASE_URL`. Copy `.env.example` to `.env.local` and adjust as needed.

## Auth (env-based, single admin)

- **Login:** Username + password on `/login`. Checked against `VITE_ADMIN_USERNAME` and `VITE_ADMIN_PASSWORD` (no backend auth).
- **Session:** On success, a flag is stored in `localStorage`; you stay logged in until you click Logout.
- **Logout:** Clears the session and redirects to `/login`.

Route protection uses SvelteKit load hooks: all routes except `/login` require the admin to be logged in (client-side check).

Default credentials: **admin** / **Hydr0drags**. Change them via env.

## Folder structure

```
admin_portal/
├── src/
│   ├── lib/
│   │   ├── api/           # API client and resources
│   │   │   ├── client.ts  # fetch wrapper (no auth)
│   │   │   └── resources.ts
│   │   ├── admin-auth.ts  # env-based login (username/password)
│   │   ├── components/    # DataTable, Button, Toast, Modal
│   │   └── stores/        # toast store
│   ├── routes/
│   │   ├── (admin)/       # Protected layout: sidebar + top bar
│   │   │   ├── dashboard/
│   │   │   ├── events/
│   │   │   ├── classes/
│   │   │   ├── racers/
│   │   │   ├── pwcs/
│   │   │   └── registrations/
│   │   └── login/
│   ├── app.css
│   └── app.html
├── static/
├── .env.example
├── .env.local
├── package.json
├── svelte.config.js
├── vite.config.ts
└── README.md
```

## Adding new admin pages

1. Add a route under `src/routes/(admin)/`, e.g. `(admin)/my-page/+page.svelte`.
2. Add a nav link in `(admin)/+layout.svelte` (`nav` array).
3. Use `$lib/api/client` (`apiGet`, `apiPost`, etc.) for requests. Add any new API helpers in `$lib/api/resources.ts`.

## Placeholder / TODO endpoints

- **PWCs:** `fetchPwcs()` returns `[]` until the backend adds `GET /admin/pwcs` or `GET /pwcs` (list all).
- **Registrations:** `fetchRegistrations()` returns `[]` until the backend adds `GET /registrations` or `GET /admin/registrations`.
- **Classes:** Classes page is a placeholder until a racing-classes endpoint exists.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (default `http://localhost:5173`) |
| `npm run build` | Production build |
| `npm run preview` | Serve production build locally |

## Styling

Plain CSS only. No Tailwind or UI frameworks. Styles live in `src/app.css` and component-scoped CSS where needed.
