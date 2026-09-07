# AbdullahAtal — Supabase Connected

This package is configured for the Supabase project URL supplied by the owner.

## Important
The included key is a Supabase Publishable key intended for browser use. Never add a `sb_secret`, service-role key, database password, Stripe secret, or webhook signing secret to this project’s client-side environment.

## Next
1. Deploy this project with a Vite-compatible host.
2. If the host asks for environment variables, set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` to the values in `.env.local`.
3. After deployment, test sign-up/login and product reads.
4. Configure Supabase Auth redirect URLs to the production site.
