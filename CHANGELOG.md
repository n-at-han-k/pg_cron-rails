## [Unreleased]

## [2.0.0] - 2026-08-04

Restructured on F(x)'s model. Every change below is breaking; there is no
upgrade path that does not touch existing job definitions.

### Changed

- **Definitions are versioned SQL, not YAML.** `db/pg_cron_jobs/<name>.yml`
  becomes `db/cron/<name>_v<NN>.sql`, holding the `cron.schedule()` call
  verbatim. A job's body was always SQL; YAML meant a SQL string inside a YAML
  scalar, so nothing could syntax-check it, dollar-quoting had to survive two
  levels of escaping, and it could not be dumped back out.
- **Migration methods renamed and reshaped.** `schedule_pg_cron_job` /
  `unschedule_pg_cron_job` / `update_pg_cron_job` become `create_cron_job` /
  `drop_cron_job` / `update_cron_job`, taking F(x)'s arguments: `version:`,
  `sql_definition:` (mutually exclusive) and `revert_to_version:`.
- **The module is `PgCron` and the gem is `pg_cron`** (was `PgCronRails` /
  `pg_cron_rails`).
- **The adapter is split** into `Adapters::Postgres` plus `Connection`, `Jobs`
  and `QueryExecutor`, matching F(x)'s layout.
- **The generator is namespaced and versioned**: `rails g pg_cron:job NAME`.
  Running it again for an existing job copies the current definition to the next
  version and writes an update migration carrying `revert_to_version`.
- `pg_cron:schedule_all_jobs` reads `db/cron/*_v*.sql` and schedules the HIGHEST
  version of each job. Globbing filenames the old way scheduled every historical
  version in turn and left whichever sorted last in place.

### Added

- **A schema dumper.** Scheduled jobs are written into `db/schema.rb` as
  `create_cron_job` lines. Without this the schema was wrong rather than merely
  incomplete: a `db:schema:load` database came up with every table and none of
  the schedules, silently.
- Reversibility. `CommandRecorder` inverts all three statements, and raises
  `ActiveRecord::IrreversibleMigration` when a drop or update has no
  `revert_to_version` instead of deleting the job.

### Fixed

- Definitions are executed as given rather than assembled by interpolating
  values into a heredoc, where a job name or command containing a quote produced
  broken SQL.
- `update_cron_job` verifies the job exists first. `cron.schedule()` would
  otherwise silently create one that was expected to be there, hiding a
  migration applied out of order.

## [1.0.1] - 2021-10-26

- Fix PgCron manual configuration


## [1.0.0] - 2021-10-19

- Initial release
