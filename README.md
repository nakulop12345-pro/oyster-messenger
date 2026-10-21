# OYSTER — Private Messenger

Minimal, responsive watch-inspired messaging web app. OYSTER is an independent project and is not affiliated with Rolex.

## Setup
1. Create a project at https://supabase.com.
2. In Supabase Dashboard → SQL Editor, paste and run all of `supabase-schema.sql`.
3. In `config.js`, replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY` with the project's Project URL and publishable/anon key. Never expose a service_role key.
4. In Supabase → Authentication → URL Configuration, add your GitHub Pages URL to Site URL and Redirect URLs.
5. In Supabase → Authentication → Providers → Email, decide whether email confirmation is required. If enabled, users must confirm their address before signing in.
6. In GitHub repository Settings → Pages, choose Deploy from a branch, branch `main`, folder `/(root)`, then Save.

## Android
Open the HTTPS GitHub Pages site in Chrome on Android and choose ⋮ → Install app or Add to Home screen. This is an installable web app, not a native APK.

## Notes
- Browser-visible Supabase publishable/anon keys are expected; RLS policies protect the database. Never use a service_role key in client-side files.
- This starter is not an audited secure messaging service. Messages are stored by Supabase and are not end-to-end encrypted. Do not use for sensitive conversations.
- Live messaging uses Supabase Realtime; if it does not activate automatically, enable the `messages` table in Database → Replication.
- Typing indicators, push notifications, attachments, password reset, and account recovery UI are not included in this first version.
