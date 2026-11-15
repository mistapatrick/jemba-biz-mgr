# Cloud deployment runbook

## Resource ownership

| Resource | Purpose | Credentials location |
|---|---|---|
| GitHub | Source code and reviewed migrations | GitHub account; Actions secrets for deployment |
| Vercel | Next.js hosting and server runtime | Vercel project environment variables |
| Supabase | PostgreSQL, Auth, RLS and storage | Supabase project; only URL/public key exposed to browser |

## Cloud deployment order

1. Create Supabase project and record URL, project reference and database password.
2. Create GitHub repository and push project.
3. Add Supabase Actions secrets to GitHub.
4. Run the migration workflow and verify success.
5. Import repository into Vercel and add public Supabase URL/key plus server-only service key.
6. Deploy Vercel application and verify `/api/health`.
7. Temporarily set the one-time bootstrap secret, redeploy and create the owner account using the API endpoint.
8. Remove the bootstrap secret and redeploy.
9. Configure Supabase SMTP, Auth site URL and redirect URLs to the Vercel domain.
10. Owner signs in and invites staff.
11. Test all roles and transaction workflows in staging before recording live business data.

## Required Vercel environment variables

`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and temporary `JEMBA_BOOTSTRAP_SECRET`.

## Required GitHub Actions secrets

`SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`.

## Operational safety

- Do not commit `.env`, `.env.local`, service-role keys, database passwords or bootstrap secrets.
- Do not expose the service-role key to client components.
- Use a staging Supabase project for migration and transaction testing.
- Back up the database and test restoration before production use.
- Review and approve SQL migrations before merging to `main`.
- Remove the one-time bootstrap secret immediately after creating the owner.
