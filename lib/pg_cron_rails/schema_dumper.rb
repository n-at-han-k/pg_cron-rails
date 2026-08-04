# frozen_string_literal: true

module PgCronRails
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
  module SchemaDumper
    def extensions(stream)
      super
      cron_jobs(stream)
    end

    def cron_jobs(stream)
      return unless PgCronRails.connection.extension_enabled?("pg_cron")

      jobs = PgCronRails.connection.cron_jobs
      return if jobs.none?

      stream.puts
      jobs.sort.each { |job| stream.puts(job.to_schema) }
    end
  end
end
