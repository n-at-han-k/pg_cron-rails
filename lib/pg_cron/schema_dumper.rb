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
  # HOOKS #tables, NOT #extensions, which is what F(x) does and for a reason
  # that is easy to get wrong. ActiveRecord::SchemaDumper#extensions is private
  # AND redefined by the PostgreSQL-specific dumper, so a module prepended to
  # ActiveRecord::SchemaDumper never intercepts it — the subclass's own
  # definition wins and the override is simply never called. The symptom is a
  # schema dump that succeeds and contains no cron section at all.
  #
  # #tables is the documented seam, and running after super means the cron block
  # lands after the tables and after F(x)'s functions — which matters, because a
  # create_cron_job line calls cron.schedule() with a command that generally
  # references those functions.
  #
  # Goes through PgCron.database — the adapter — like everything else. It used
  # to call PgCron.connection.extension_enabled? / .cron_jobs, which were
  # methods on the raw connection this gem opened before; against the adapter
  # they are NoMethodError, and a schema dump simply produced no cron section
  # while looking like it had worked. The adapter's #jobs already returns [] when
  # pg_cron is absent, so there is no separate guard to get wrong.
  module SchemaDumper
    def tables(stream)
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
