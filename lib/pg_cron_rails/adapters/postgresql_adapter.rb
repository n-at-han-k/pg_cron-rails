# frozen_string_literal: true

require "delegate"
require "pg_cron_rails/job"

module PgCronRails
  module Adapters
    class PostgresqlAdapter < SimpleDelegator
      # Every scheduled job, for the schema dumper.
      #
      # jobname can be NULL — cron.schedule() has an arity that does not take
      # one — and such a job cannot be expressed as create_cron_job, which is
      # keyed by name. Those are skipped rather than dumped wrongly.
      CRON_JOBS_QUERY = <<~SQL
        SELECT jobname, schedule, command, database, username, active
        FROM cron.job
        WHERE jobname IS NOT NULL
        ORDER BY jobname
      SQL

      # @return [Array<PgCronRails::Job>]
      def cron_jobs
        execute(CRON_JOBS_QUERY).map { |row| PgCronRails::Job.new(row) }
      end

      # The definition is executed AS GIVEN. It is the cron.schedule() call from
      # db/cron/<name>_v01.sql, so the schedule, the command and any quoting are
      # that file's business — this neither parses nor rewrites it.
      #
      # That is the substantive change from the YAML era, where this method
      # assembled SQL by interpolating hash values into a heredoc: a job name or
      # command containing a quote produced broken SQL at best.
      def create_cron_job(sql_definition)
        execute(sql_definition)
      end

      def drop_cron_job(name)
        execute("SELECT cron.unschedule(#{quote(name.to_s)})")
      end

      # cron.schedule() against an existing jobname replaces it, so an update is
      # just the create — but only if the job is actually there. Scheduling one
      # that was expected to exist would silently create it, hiding a migration
      # applied out of order.
      def update_cron_job(name, sql_definition)
        transaction do
          unless cron_job_exists?(name)
            raise PG::InternalError, "ERROR: could not find valid entry for job #{quote(name.to_s)}"
          end

          execute(sql_definition)
        end
      end

      private

      def cron_job_exists?(name)
        execute("SELECT 1 FROM cron.job WHERE jobname = #{quote(name.to_s)}").any?
      end
    end
  end
end
