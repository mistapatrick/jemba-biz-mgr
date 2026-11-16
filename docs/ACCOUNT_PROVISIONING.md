# Initial Jemba account provisioning (cloud)

The first bootstrap creates two separate identities in the same Jemba business workspace:

- Developer: `super_admin` (platform monitoring and technical support)
- Jemima Bangoji: `owner_admin` (business operations)

They must use different email addresses and separate passwords. Both passwords must be at least 14 characters.

## Required Vercel Production environment variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` (the project's publishable/anon key)
- `SUPABASE_SERVICE_ROLE_KEY` (server-only secret key; never expose to browser code)
- `JEMBA_BOOTSTRAP_SECRET` (random one-time secret, at least 32 random bytes)

After adding/changing variables, redeploy the Vercel project.

## Run the one-time cloud request

Send a POST request to `https://YOUR-VERCEL-DOMAIN/api/bootstrap` with:

`Authorization: Bearer YOUR_ONE_TIME_SECRET`

JSON body:

```json
{
  "businessName": "Jemba Supply and Solutions Nigeria",
  "developerName": "Patrick Anekwe",
  "developerEmail": "YOUR_DEVELOPER_EMAIL",
  "developerPassword": "YOUR_UNIQUE_PASSWORD_AT_LEAST_14_CHARACTERS",
  "ownerName": "Jemima Bangoji",
  "ownerEmail": "JEMIMA_EMAIL_ADDRESS",
  "ownerPassword": "HER_UNIQUE_PASSWORD_AT_LEAST_14_CHARACTERS"
}
```

Use different email addresses for developer and owner. Never paste passwords or secrets into GitHub, source files, chat, or public logs. The endpoint confirms both email addresses in Supabase Auth as part of this controlled initial provisioning operation.

On HTTP 201, securely record the returned business ID, then immediately delete `JEMBA_BOOTSTRAP_SECRET` from Vercel and redeploy. Keep `SUPABASE_SERVICE_ROLE_KEY` in Vercel because other trusted server-side administration may need it. Do not delete or expose it.

The SQL migration `202611160001_bootstrap_developer_and_owner.sql` must be applied before calling the endpoint. The database function is service-role-only and refuses to create a second initial workspace.

If provisioning fails, inspect the JSON error response and Vercel function logs. The endpoint attempts to delete any Auth users it created when the database transaction fails.
