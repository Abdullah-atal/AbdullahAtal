# AbdullahAtal V14 — Phone Launch Package

## 1. Supabase
Run migrations through `v13_migration.sql`, then run `launch_check.sql` and review the RLS policies.

## 2. Environment
Create the production Supabase project and keep secret/service-role keys out of the browser. Put provider secrets in trusted server-side functions.

## 3. Payments
Configure the V7 Stripe Edge Functions with production keys and webhook signing secret. Test successful, failed, duplicate, refunded and cancelled payments.

## 4. Delivery
Connect your chosen carrier/API and send delivery events into `delivery_events`.

## 5. Payouts
Set the actual AbdullahAtal commission, connect a payout provider, and test seller settlement.

## 6. Deploy from phone
Upload the project to your chosen static host, or use a Git-based deployment service. The included `vercel.json` and `netlify.toml` provide basic SPA routing.

## 7. Install on Android
Open the production HTTPS site in a supported browser and use its “Install app” / “Add to Home screen” action. V14 includes a web manifest and service worker.

## 8. Before launch
Verify domain, HTTPS, Auth redirect URLs, email settings, RLS, backups, monitoring, rate limits, policies, support contact, refund rules, delivery estimates, seller onboarding, and legal/business requirements.

V14 makes the project installable and deployment-oriented. External provider accounts and business verification still require your real accounts and credentials.
