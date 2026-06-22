# Supabase setup

The database for AnDaLoeS for Generators. Schema lives in `migrations/`.

## 1. Create the project (one time)

1. Go to [supabase.com](https://supabase.com) → sign up → **New project**.
2. **Region: EU (Frankfurt)** — closest to Egypt, lowest latency.
3. Set a strong database password and save it.
4. After it provisions, go to **Project Settings → API** and copy:
   - **Project URL**
   - **anon / publishable key**

   These two go into the Flutter app config (and can be shared with the
   developer — the anon key is safe for client apps; RLS protects the data).

## 2. Apply the schema

**Option A — SQL editor (easiest):**
Open **SQL Editor** in the Supabase dashboard and run, in order:
1. `migrations/0001_init_schema.sql`
2. `migrations/0002_rls_policies.sql`

**Option B — Supabase CLI:**
```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

## 3. Configure auth (phone OTP)

In **Authentication → Providers**, enable **Phone** and connect an SMS
provider (e.g. Twilio, or a local Egyptian SMS gateway). Phone + OTP is the
app's only sign-in method.

## 4. Storage buckets

Create two buckets in **Storage**:
- `generator-photos` — **public** (listing images).
- `company-documents` — **private** (verification files; readable only by the
  owning company and admins).

## Notes
- Sensitive writes (`payments`, `commissions`, company `verification_status`)
  are performed by **Edge Functions** with the service role, never directly by
  the app. See `docs/DATA_MODEL.md`.
- The first admin user: after signing up, set their `profiles.role` to `admin`
  manually in the dashboard so you can approve companies.
