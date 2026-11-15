# Cloud deployment commands and operations

This application is designed to run on GitHub + Vercel + Supabase. No always-on local server is required.

## GitHub push (from any machine with Git installed)

```bash
git add .
git commit -m "Deploy Jemba Business Manager"
git push origin main
```

## Apply database migrations

Preferred: GitHub → Actions → Apply Supabase database migrations → Run workflow.

The workflow uses GitHub secrets `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` and `SUPABASE_DB_PASSWORD` and runs `supabase db push --linked --yes` against the cloud project.

## Owner provisioning

Use the protected `POST https://YOUR-VERCEL-DOMAIN/api/bootstrap` endpoint documented in `README.md`. This is a one-time operation. Remove `JEMBA_BOOTSTRAP_SECRET` from Vercel immediately after successful provisioning and redeploy.

## Staff account management

After the owner signs in, use the User administration screen to invite staff. Supabase Auth SMTP must be configured for email invitations.

## Vercel deployment

Connect the GitHub repository to Vercel once. Vercel then builds and deploys each push to the configured production branch. Set the required environment variables in Vercel Project Settings; never store secrets in GitHub source files.

## Operational checks

- GitHub Actions quality workflow: install, typecheck, build.
- GitHub Actions migration workflow: apply reviewed SQL migrations.
- Vercel deployment: verify Ready status and inspect build/runtime logs.
- Supabase: verify migration history, Auth users, RLS and database logs.
- Application: verify `/api/health`, sign-in, dashboard and one test transaction in a non-production/staging project before real use.
