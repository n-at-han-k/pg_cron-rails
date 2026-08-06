# pg_cron

[![Build Status](https://github.com/n-at-han-k/pg_cron-rails/actions/workflows/main.yml/badge.svg)](https://github.com/n-at-han-k/pg_cron-rails/actions/workflows/main.yml)

pg_cron adds methods to `ActiveRecord::Migration` to create and manage
[pg_cron](https://github.com/citusdata/pg_cron) schedules in Rails.

Using pg_cron, you can keep your database's own scheduler under version control
alongside the rest of your schema. This gem provides a convention for versioning
job definitions that keeps your migration history consistent and reversible and
avoids duplicating SQL strings across migrations. Jobs are dumped into
`db/schema.rb`, so a database loaded from the schema comes up with its schedules
already in place. As an added bonus, you define the job in a SQL file, meaning
you get full SQL syntax highlighting in the editor of your choice and can easily
test the statement in `psql` during development.

pg_cron ships with support for PostgreSQL, which is the only engine pg_cron the
extension runs on. The adapter is still configurable (see
`PgCron::Configuration`) and has a minimal interface (see
`PgCron::Adapters::Postgres`).

This gem is modelled closely on [F(x)][fx], and the two are designed to be used
together: definitions live in `db/cron` next to F(x)'s `db/functions`, the
generators behave the same way, and both dump into `db/schema.rb`.

[fx]: https://github.com/teoljungberg/fx

## Great, how do I schedule a job?

You've got a `DELETE` you'd like Postgres to run every night. You can create the
migration and the corresponding definition file with the following command:

```sh
% rails generate pg_cron:job purge_old_sessions
      create  db/cron/purge_old_sessions_v01.sql
      create  db/migrate/[TIMESTAMP]_create_cron_job_purge_old_sessions.rb
```

Edit the `db/cron/purge_old_sessions_v01.sql` file with the `cron.schedule()`
call that defines your job. In our example, this might look something like this:

```sql
SELECT cron.schedule(
    'purge_old_sessions',
    '0 3 * * *',
    $job$DELETE FROM sessions WHERE expires_at < now()$job$
);
```

The job's name is its identity: pg_cron keys on `jobname`, so scheduling over an
existing name replaces that job rather than adding a second one.

The generated migration contains a `create_cron_job` statement. It is reversible
and the schedule will be dumped into your `schema.rb` file.

```sh
% rake db:migrate
```

## Cool, but what if I need to change a job?

Run that same generator once more:

```sh
% rails generate pg_cron:job purge_old_sessions
      create  db/cron/purge_old_sessions_v02.sql
      create  db/migrate/[TIMESTAMP]_update_cron_job_purge_old_sessions_to_version_2.rb
```

pg_cron detected that we already had an existing `purge_old_sessions` job at
version 1, created a copy of that definition as version 2, and created a
migration to update to the version 2 schedule. All that's left for you to do is
tweak the schedule or command in the new definition and run the
`update_cron_job` migration.

The update is a single `cron.schedule()` call, not an unschedule followed by a
schedule — there is no window in which the job does not exist, so a
frequently-firing job doesn't miss a run while the migration is in flight. It
also fails loudly if the job isn't there to begin with, rather than quietly
creating it.

## I don't need this job anymore. Make it go away.

pg_cron gives you `drop_cron_job` too:

```ruby
def change
  drop_cron_job :purge_old_sessions, revert_to_version: 2
end
```

`revert_to_version` is what makes the migration reversible: rolling back
re-creates the job from `db/cron/purge_old_sessions_v02.sql`. Without it,
rolling back a drop or an update raises
`ActiveRecord::IrreversibleMigration` rather than leaving the schedule missing.

## What if I want to write the SQL inline?

All three statements take `sql_definition:` in place of `version:`, for when the
definition doesn't belong in a file — most often in `db/schema.rb`, which is
where the dumper writes them:

```ruby
create_cron_job :purge_old_sessions, sql_definition: <<-'SQL'
  SELECT cron.schedule(
      'purge_old_sessions',
      '0 3 * * *',
      $job$DELETE FROM sessions WHERE expires_at < now()$job$
  );
SQL
```

`version:` and `sql_definition:` are mutually exclusive; passing both raises
`ArgumentError`.

## What about databases without the extension?

Every statement checks whether pg_cron is installed and does nothing when it
isn't. A migration that schedules a job still runs against a test database or an
environment where cron isn't wanted, without needing its own guard.

## Configuration

No configuration is needed. Statements run over the application's own
`ActiveRecord::Base` connection, which is the connection that can see them:
`cron.job` lives in whatever `cron.database_name` points at — your application's
database — and pg_cron puts row-level security on that table filtering by
username, so jobs created as a different role would be invisible to both the
application and the schema dumper.

To substitute your own adapter:

```ruby
# config/initializers/pg_cron.rb
PgCron.configure do |config|
  config.adapter = PgCron::Adapters::Postgres.new
end
```

## Rake tasks

```sh
% rake pg_cron:schedule_all_jobs
```

Schedules every job in `db/cron` at its highest version. Useful for bringing an
environment in line with the definitions without replaying migrations.

```sh
% rake pg_cron:up[1.3.0]
% rake pg_cron:down[1.3.0]
```

Install and enable, or disable and remove, the pg_cron extension in a local
development database. These are Homebrew- and macOS-only, refuse to run outside
`RAILS_ENV=development`, and edit `shared_preload_libraries` in your
`postgresql.conf` before restarting the service.

## Version Support

**Ruby:** 2.7+

**Rails:** 6.0+ (`activerecord`, `activesupport` and `railties`)

**PostgreSQL:** any version supported by the pg_cron extension you install.

## Upgrading from 1.x

2.0 restructured the gem on F(x)'s model and every change is breaking. See the
[CHANGELOG](CHANGELOG.md) for the full list; in short:

- `db/pg_cron_jobs/<name>.yml` becomes `db/cron/<name>_v<NN>.sql`, holding the
  `cron.schedule()` call verbatim.
- `schedule_pg_cron_job` / `unschedule_pg_cron_job` / `update_pg_cron_job`
  become `create_cron_job` / `drop_cron_job` / `update_cron_job`, taking
  `version:`, `sql_definition:` and `revert_to_version:`.
- The module is `PgCron` and the gem is `pg_cron` (was `PgCronRails` /
  `pg_cron_rails`).
- The generator is `rails generate pg_cron:job NAME` (was
  `rails generate pg_cron_job NAME`).

## Methods

The methods added to `ActiveRecord::Migration` are defined in
[PgCron::Statements](lib/pg_cron/statements.rb).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
