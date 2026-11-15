# Cloud account provisioning

## Initial owner account

The initial owner account is created through the one-time cloud endpoint `POST /api/bootstrap`. See the Cloud deployment section in the root README for the exact request body and steps. The endpoint requires the temporary `JEMBA_BOOTSTRAP_SECRET` and server-only `SUPABASE_SERVICE_ROLE_KEY` environment variables. It calls the atomic `bootstrap_initial_business` database function and refuses to create a second initial business.

Immediately remove `JEMBA_BOOTSTRAP_SECRET` from Vercel and redeploy after the owner account is created.

## Staff accounts

The owner signs into the deployed application and uses User administration to invite staff. Available staff roles are:

- `customer_relationship_officer`
- `cashier`
- `storekeeper`
- `supply_chain_manager`

Supabase Auth SMTP must be configured and the Vercel production URL must be added to Supabase Auth Site URL and Redirect URLs. The staff invitation operation uses the server-side service-role key and must never be moved into browser code.

## Developer super administrator

Do not create a developer super-admin by editing browser metadata or changing a profile row from the client. Provisioning a developer account should be a controlled server-side operation after the owner has approved the access. Keep developer technical access separate from routine owner financial access and audit any exceptional access.
