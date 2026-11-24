# Bigma LMS prototype

Corporate learning app for Bigma clients: employees take assigned classes (video, PDF, pre test, post test), earn points and certificates; HR invites staff, builds classes, assigns them with deadlines and exports reports. Design: style B "Bingkai".

- `app/` Flutter app (web first, phone and desktop layouts).
- `supabase/` database schema with row level security, sample data SQL, `activate` edge function. **Not connected yet.**
- `tools/` sample data and media generators, local test scripts, Vercel build script.

## Run modes
- **Demo mode (current):** no Supabase keys. All data is fictional sample data held in the browser and resets on reload.
- **Real mode (later):** set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in Vercel, apply `supabase/migrations/0001_schema.sql`, then `supabase/seed.sql`, and deploy `supabase/functions/activate`.

## Demo accounts
Password `BigmaDemo2026!` for `rina.wulandari@contohsejahtera.example` (employee) and `hendra.dharma@contohsejahtera.example` (HR). First login can be tried with `maya.anggraini@contohsejahtera.example` via "Aktifkan akun".

## Local build
```
cd app && flutter pub get && flutter build web --release
node ../tools/serve.js build/web 8080
```
