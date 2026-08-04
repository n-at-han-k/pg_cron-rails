# frozen_string_literal: true

module PgCron
  # Writes scheduled jobs into db/schema.rb.
  #
  # F(x)'s SchemaDumper with `functions`/`triggers` replaced by `jobs`. Hooking
  # #tables rather than #extensions is F(x)'s choice and is load-bearing:
  # #extensions is private AND redefined by the PostgreSQL-specific dumper, so a
  # module prepended to ActiveRecord::SchemaDumper never intercepts it and the
  # dump silently comes out with no cron section.
  #
  # Emitted after super, so the cron block follows the tables and F(x)'s
  # functions — which matters, because a create_cron_job line schedules a command
  # that generally calls them.
  #
  # @api private
  module SchemaDumper
    def tables(stream)
      super

      jobs(stream)
    end

    private

    def jobs(stream)
      dumpable_jobs_in_database = PgCron.database.jobs

      dumpable_jobs_in_database.each do |job|
        stream.puts
        stream.puts(job.to_schema)
      end
    end
  end
end
