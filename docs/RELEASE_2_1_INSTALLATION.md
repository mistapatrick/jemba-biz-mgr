# Jemba Business Manager — Release 2.1 installation

## Contents

- `supabase/migrations/202611170001_phase21_accounting_foundation.sql`
- `supabase/verification/phase21_post_migration_checks.sql`

## What this release changes

1. Adds `accounting_periods` with explicit date ranges and open/closed status. It does not create a fiscal year automatically because Jemba's financial year start has not yet been confirmed.
2. Adds journal metadata for accounting period linkage, posting timestamp, reversal linkage and idempotency.
3. Adds moving weighted-average inventory valuation foundation tables.
4. Creates explicitly **unverified** legacy inventory snapshots from current product quantity and cost. These snapshots do not post journals and must be reconciled before WAC is activated in Release 2.2.
5. Corrects `v_trial_balance` and `v_income_statement` so only posted journal entries are aggregated.
6. Adds tenant-scoped read-only access to the new foundation tables. No direct authenticated writes are granted.

## Important limitations

This is the database foundation release, not the activation of the new WAC posting engine. Existing `record_sale`, `receive_stock` and `create_product` functions are intentionally unchanged in this release. They continue to use the current implementation until the dedicated WAC transaction functions are delivered and tested in the next release. Do not represent current COGS as WAC-based yet.

No accounting period is automatically closed or opened. No opening balances are invented. No historical journal or stock movement is rewritten. No tax rates are configured in this release.

## Before installation

1. Confirm a recent Supabase backup exists and that restoration is possible.
2. Create/use a staging Supabase project with the same migrations and a copy of representative data.
3. Review the SQL migration and run it in staging first.
4. Check that the existing migration workflow uses `supabase db push --linked --yes` and that GitHub Actions secrets are valid.
5. Do not copy the whole release folder over the repository. Copy only the new migration and verification file, preserving all other project files.

## Integration into the existing repository

From the existing project root, the release adds these two files:

- `supabase/migrations/202611170001_phase21_accounting_foundation.sql`
- `supabase/verification/phase21_post_migration_checks.sql`

Then run locally against a linked **staging** Supabase project:

```bash
npx supabase db push --linked
```

Do not run this against production until staging checks pass and the business owner approves the release. The repository's existing GitHub Actions workflow will apply migrations pushed to `main`, so production push is the production deployment action.

## Post-migration verification

Run `supabase/verification/phase21_post_migration_checks.sql` in the Supabase SQL Editor on staging. Review every result. The inventory snapshot row count should correspond to the number of existing products, but values are unverified snapshots and must be reconciled against a physical stock count and accounting records.

Also test that an ordinary authenticated user can read only rows for their own business and cannot insert/update/delete the new foundation tables directly.

## Rollback

Do not drop these tables or revert the views if the migration has been applied to production without first assessing dependencies and data. Prefer a forward-fix migration. The migration is additive apart from replacing the definitions of the two reporting views with corrected definitions.
