# Shop platform (fresh start)

Folders
- `supabase/`: `01_schema.sql` (all tables), `02_seed.sql` (a test shop)
- `storefront/`: the Mini App (Vite + React) and `api/shop.ts` (server function)

Order of work: Supabase, then GitHub, then Vercel, then the bot's menu button.
Secrets (bot tokens, Supabase secret key) go only in Supabase's SQL editor (the test bot token)
and in Vercel's environment variables. Never in files or GitHub.
