# frozen_string_literal: true

module PgCron
  # Writes scheduled jobs into db/schema.rb, the way F(x) writes functions and
  # triggers.
  #
  # Without this the schema is WRONG rather than merely incomplete. The Rails
  # dumper knows about tables, indexes and extensions and nothing else, so a
  # database built with db:schema:load comes up with every table and none of the
  # schedules — silently, and in an environment where nobody is watching cron.
  #
  # Dumped AFTER the extensions block, because create_cron_job calls
  # cron.schedule() and that function only exists once pg_cron is installed.
  #
  # Goes through PgCron.database — the adapter — like everything else. It used
  # to call PgCron.connection.extension_enabled? / .cron_jobs, which were
  # methods on the raw connection this gem opened before; against the adapter
  # they are NoMethodError, and a schema dump simply produced no cron section
  # while looking like it had worked. The adapter's #jobs already returns [] when
  # pg_cron is absent, so there is no separate guard to get wrong.
  module SchemaDumper
    def extensions(stream)
      super
      cron_jobs(stream)
    end

    def cron_jobs(stream)
      jobs = PgCron.database.jobs
      return if jobs.none?

      stream.puts
      jobs.sort.each { |job| stream.puts(job.to_schema) }
    end
  end
end
