# HydroDrags Admin Portal

A **SvelteKit** (TypeScript) web app for event administration—built as the companion to the [HydroDrags](https://github.com/your-username/hydrodrags) Flutter mobile app. It talks to the same FastAPI backend and gives staff a full desktop UI for managing events, racers, registrations, spectators, and live sessions.

**Part of my portfolio:** This project demonstrates a production-style admin dashboard: auth, CRUD, real-time–style timers (speed sessions), QR scanning for tickets, and a clean separation between a mobile app and an internal tool that share one API.

---

## Tech stack

- **Frontend:** SvelteKit, TypeScript, Vite  
- **Styling:** Plain CSS (no Tailwind or UI framework)  
- **Backend:** FastAPI (separate repo); admin requests use an API key header  
- **Auth:** Env-based login (username/password) with session stored in `localStorage`; all admin routes are protected client-side  

---

## Features

- **Dashboard** — Overview of events, revenue, and registrations  
- **Events** — Create and edit events; manage registrations and format-specific flows (brackets for head-to-head, speed sessions for top-speed)  
- **Speed sessions** — Start/pause/stop sessions, set duration, enter racer speeds, live countdown timer synced with the server  
- **Spectators & tickets** — Day/weekend pass totals, ticket list, manual scan input, and camera QR scanning  
- **Racers & PWC registry** — View and edit racers and watercraft  
- **Registrations** — Per-event signups and status  
- **Payments** — Payment history and status  

---

## Quick start

```bash
cd admin_portal
cp .env.example .env.local   # then edit with your API URL and credentials
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173). You’ll be redirected to `/login` if not authenticated.

---

## Environment variables

Configure `.env.local` (never commit it). See `.env.example` for the full list.

| Variable | Description |
|----------|-------------|
| `VITE_API_BASE_URL` | Backend API base URL (e.g. `http://localhost:8000`) |
| `VITE_ADMIN_USERNAME` | Admin login username |
| `VITE_ADMIN_PASSWORD` | Admin login password |
| `VITE_ADMIN_API_KEY` | Secret key sent as `X-Admin-Key` on all admin API requests; must match the backend |

No example passwords or keys are included in the repo. Set these locally for development or deployment.

---

## Auth

- **Login:** Username and password on `/login`, checked against the env variables above (no backend auth for login).  
- **Session:** On success, a flag is stored in `localStorage`; you stay logged in until you click **Logout**.  
- **API:** All requests to the backend use `VITE_ADMIN_API_KEY` in the `X-Admin-Key` header.  

Route protection is done in SvelteKit load hooks: every route except `/login` requires the admin to be logged in (client-side check).

---

## Project structure

```
admin_portal/
├── src/
│   ├── lib/
│   │   ├── api/           # API client and endpoint modules (events, speed, tickets, etc.)
│   │   ├── admin-auth.ts  # Env-based login and session
│   │   ├── components/    # DataTable, Button, Toast, Modal
│   │   └── stores/
│   ├── routes/
│   │   ├── (admin)/       # Protected layout: sidebar + main content
│   │   │   ├── dashboard/
│   │   │   ├── events/    # List, create, edit, manage (brackets / speed)
│   │   │   ├── spectators/
│   │   │   ├── racers/
│   │   │   ├── registrations/
│   │   │   ├── payments/
│   │   │   └── ...
│   │   └── login/
│   ├── app.css
│   └── app.html
├── static/
├── .env.example
├── package.json
├── svelte.config.js
├── vite.config.ts
└── README.md
```

---

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server at `http://localhost:5173` |
| `npm run build` | Production build |
| `npm run preview` | Serve the production build locally |

---

## License

Private / portfolio use. See the root HydroDrags repository for project-wide license and contribution notes.
