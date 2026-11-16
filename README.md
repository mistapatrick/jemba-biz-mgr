# Jemba Business Manager

Cloud-hosted business operations application for Jemba Supply and Solutions Nigeria.

## Cloud architecture

- **Source control:** GitHub
- **Application hosting:** Vercel (Next.js server runtime)
- **Database and authentication:** Supabase PostgreSQL and Supabase Auth
- **Database deployment:** GitHub Actions + Supabase CLI
- **Client delivery:** Responsive web application / installable PWA

The deployed application does not require a local server or a computer to remain switched on. A developer workstation is only needed if you choose to edit source code locally. Database migrations can be applied from GitHub Actions.

## Deployment prerequisites

Create these cloud resources before deploying:

1. A GitHub repository containing this project.
2. A Supabase project in the intended region.
3. A Vercel project imported from the GitHub repository.
4. Supabase Auth email settings configured with a production SMTP provider before inviting staff.

## GitHub repository secrets

In GitHub → Settings → Secrets and variables → Actions, add:

- `SUPABASE_ACCESS_TOKEN`: personal access token from Supabase.
- `SUPABASE_PROJECT_REF`: project reference from the Supabase project URL.
- `SUPABASE_DB_PASSWORD`: database password for the Supabase project.

The `Apply Supabase database migrations` workflow runs when migration files change on `main`, or when manually dispatched. Review migration SQL before merging it to `main`. Do not configure this workflow to apply unreviewed changes to a production database.

## Vercel environment variables

In Vercel → Project → Settings → Environment Variables, configure for Production, Preview and Development as appropriate:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-only; needed for staff invitations and one-time owner bootstrap)
- `JEMBA_BOOTSTRAP_SECRET` (temporary; only needed for initial owner provisioning)

Never prefix privileged secrets with `NEXT_PUBLIC_`. Never commit real credentials to GitHub. Redeploy after changing environment variables.

## Deploy the database

1. Push this repository to GitHub.
2. Add the three Supabase GitHub Actions secrets above.
3. Open GitHub → Actions → Apply Supabase database migrations → Run workflow.
4. Confirm the workflow completes successfully before deploying the application.

The workflow applies all pending files in `supabase/migrations/` to the linked cloud Supabase project. The workflow uses `supabase db push`; it does not reset or drop the production database.

## Deploy the application

1. In Vercel, select **Add New → Project**.
2. Import the GitHub repository.
3. Select the Next.js framework preset. Keep the standard build command `npm run build` and install command `npm ci`.
4. Add the Vercel environment variables listed above.
5. Deploy. Subsequent pushes to the connected production branch trigger Vercel deployments automatically.
6. Verify `/api/health` and sign-in after deployment.

## Create the first owner account in the cloud

This project includes a one-time protected cloud endpoint at `POST /api/bootstrap`. It creates the initial Jemba business and the owner login using the server-side Supabase service-role key. It refuses to run after a business workspace already exists.

1. Generate a long random secret (at least 32 random bytes).
2. Add it to Vercel as `JEMBA_BOOTSTRAP_SECRET` and ensure `SUPABASE_SERVICE_ROLE_KEY` is present.
3. Redeploy Vercel so the variables are loaded.
4. Send one POST request to `https://YOUR-VERCEL-DOMAIN/api/bootstrap` with `Authorization: Bearer YOUR_ONE_TIME_SECRET` and JSON body:

```json
{
  "businessName": "Jemba Supply and Solutions Nigeria",
  "ownerName": "Jemima Bangoji",
  "email": "OWNER_EMAIL_ADDRESS",
  "password": "A-unique-password-at-least-14-characters"
}
```

5. Save the returned business ID in the owner's secure records.
6. Immediately remove `JEMBA_BOOTSTRAP_SECRET` from Vercel and redeploy. The endpoint also checks that no business exists, so it cannot create a second initial workspace.
7. Sign in at `/login` and invite staff from User administration. Configure Supabase SMTP first so invitations can be delivered reliably.

Do not put the bootstrap secret or service-role key in source code, GitHub files, browser JavaScript, or a public issue.

## Cloud operation and maintenance

- GitHub is the source of truth for application code and reviewed database migrations.
- Vercel serves the app and executes server-side actions and API routes.
- Supabase stores business data, authenticates users and enforces row-level security.
- Use Supabase dashboard SQL editor only for reviewed emergency administration, not as a substitute for committed migrations.
- Configure Supabase database backups/Point-in-Time Recovery according to the selected plan and verify restoration periodically.
- Configure custom domain and HTTPS in Vercel when ready.
- Configure production SMTP, Auth redirect URLs, password policies and rate limits in Supabase.
- Monitor Vercel deployment logs, Supabase logs and GitHub Actions runs.

## Current application scope

The repository contains the implemented MVP screens and database operations for sign-in, user invitations, customers, products, POS sales, expenses, stock receiving primitives, dashboard metrics and basic ledger reporting. Some enterprise modules in the original brief require additional business workflows and must not be represented as complete until their screens, transaction functions, tests and reconciliations have been implemented. See `docs/IMPLEMENTED_AND_PENDING.md`.

## Verification

A GitHub Actions quality workflow runs `npm ci`, TypeScript checking and a Next.js production build on pushes and pull requests. A successful deployment is confirmed only when the GitHub Actions workflow and Vercel deployment both report success. This repository has not been connected to Jemba's actual GitHub, Vercel or Supabase accounts from this workspace, so no cloud deployment or live database test is claimed here.


## Initial developer and owner provisioning

The first cloud bootstrap creates separate `super_admin` and `owner_admin` identities. Apply migration `202611160001_bootstrap_developer_and_owner.sql`, configure the four Vercel environment variables, redeploy, and follow `docs/ACCOUNT_PROVISIONING.md`. Remove the one-time bootstrap secret after HTTP 201.
