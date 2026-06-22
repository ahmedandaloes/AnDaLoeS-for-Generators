# AnDaLoeS for Generators — Architecture

A mobile marketplace for renting electrical **generators** in Egypt. Owners
(starting with one family fleet, later open to any owner) list generators;
customers request rentals; the platform takes a commission on each completed
rental.

> **Business model in one line:** a commission marketplace — you connect
> generator owners with customers and earn a percentage on every completed
> rental, without operating the generators yourself.

---

## 1. Goals & constraints

- **Platforms:** Android + iOS from one codebase.
- **Market:** Egypt — Arabic-first UI (RTL), phone-based login, local payment
  rails.
- **Team:** solo founder at the start → optimize for speed *and* a clean
  scaling path.
- **Code quality:** feature-first architecture to avoid "spaghetti code".

### Egypt-specific decisions (do not skip)

| Concern | Decision | Reason |
|---|---|---|
| Payments | **Paymob** (primary), **Fawry** (cash/kiosk) | Stripe & PayPal are **not usable** for collecting money in Egypt. Paymob and Fawry are the real local gateways. |
| Auth | **Phone number + OTP** | Egyptian users expect phone login, not email. |
| Language | **Arabic-first**, English optional | Most users are Arabic speakers; design RTL from day one. |
| Maps | **Google Maps** | Location of generators and delivery distance. |

---

## 2. Technology stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile app | **Flutter** (Dart) | One codebase, strong RTL/Arabic support. |
| State management | **Riverpod v2** | Testable, composable, fits feature-first layout. |
| Routing | **go_router** | Declarative, deep-link friendly. |
| Backend (MVP) | **Supabase** | Postgres + Auth (phone OTP) + Storage + Row Level Security + Realtime. No server to write at first. |
| Server logic (later) | **Supabase Edge Functions** → **NestJS** | For commission/payout/pricing rules as they grow. |
| Payments | **Paymob**, **Fawry** | Added after the core rental loop works. |
| Notifications | **Firebase Cloud Messaging** | Free push for both platforms. |
| Maps | **Google Maps SDK** | Generator location & coverage. |
| Localization | `intl` + ARB files | Arabic + English. |

### Why Supabase over Firebase or a custom backend *now*

- A marketplace is **relational** (owners ↔ generators ↔ rental requests ↔
  payments ↔ commissions). Postgres models this cleanly; Firebase's document
  store gets messy fast for this shape of data.
- As a solo founder you get auth + database + storage + auto-generated APIs
  without writing a server.
- **Escape hatch:** when business logic grows (pricing rules, payouts, your
  commission engine), put a thin **Edge Function / NestJS** layer in front of
  the same Postgres database. The app does not get rewritten — you start fast
  *and* keep the path to scale.

---

## 3. Feature-first project structure

Each feature is self-contained in three layers (data / domain / presentation)
and **never reaches into another feature's internals** — features communicate
only through `core` or shared domain models. This is what keeps the codebase
clean as it grows.

```
lib/
├── core/                  # shared building blocks
│   ├── config/            # env, constants, Supabase client setup
│   ├── theme/             # colors, typography, RTL theme
│   ├── routing/           # go_router config
│   ├── network/           # API client, error handling
│   ├── localization/      # intl / ARB (ar, en)
│   └── widgets/           # shared reusable widgets
│
├── features/
│   ├── auth/              # phone OTP login
│   │   ├── data/          # repositories, data sources
│   │   ├── domain/        # entities, business rules
│   │   └── presentation/  # screens, widgets, riverpod providers
│   │
│   ├── generators/        # browse & view available generators
│   ├── rental_request/    # THE core flow: request → accept → complete
│   ├── owner_dashboard/   # owners manage their generators & requests
│   ├── payments/          # Paymob / Fawry (added after MVP)
│   └── profile/           # user profile & settings
│
└── main.dart
```

### Layer responsibilities

- **data** — talks to Supabase / external APIs, maps JSON ↔ models.
- **domain** — pure Dart: entities and business rules, no Flutter/Supabase
  imports. Easy to unit-test.
- **presentation** — screens, widgets, and Riverpod providers that hold UI
  state.

**One rule to prevent spaghetti:** dependencies point *inward only* —
presentation → domain → data. Domain never imports Flutter or Supabase.

---

## 4. High-level flow (core rental loop — MVP)

```
Customer                Platform (Supabase)            Owner
   |                          |                          |
   |-- phone OTP login ------>|                          |
   |-- browse generators ---->|                          |
   |-- request rental ------->| create rental_request    |
   |                          |---- notify (FCM) ------->|
   |                          |<--- accept / reject -----|
   |<------- notify ----------|                          |
   |-- (cash on delivery) --->| mark completed           |
   |                          | record commission        |
```

Online payment (Paymob/Fawry) replaces "cash on delivery" in a later phase.

---

## 5. Scaling path

1. **MVP:** Flutter + Supabase, core rental loop, manual/cash settlement.
2. **Payments:** integrate Paymob + Fawry; record commission automatically.
3. **Owner self-service:** owner dashboard, onboarding flow for new partners.
4. **Business logic layer:** move pricing, payouts, and commission rules into
   Edge Functions / NestJS as they get complex.
5. **Operational scale:** read replicas, caching, analytics, fraud checks.

See `ROADMAP.md` for the phased plan and `DATA_MODEL.md` for the schema.
