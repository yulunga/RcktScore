# Manual test fixtures

These scripts are opt-in and must not be part of production migrations.

## Personal Plus match history

`testpersonal_plus_matches.sql` creates ten completed demo matches for the existing personal account `testpersonal@hitnscore.com`, split across squash, racketball, and tennis. It tags them with referee name `Plus Demo Data`, removes only an earlier copy of that tagged fixture, and does not change the user's plan or password.

Apply it to the intended non-production Supabase database with the SQL editor or:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f testing/fixtures/testpersonal_plus_matches.sql
```

Set the account to Personal Plus separately through the root-admin User Accounts profile before testing the 50-match history and Performance view. Switching it back to Personal Free should show three readable matches and one locked teaser.
