# frozen_string_literal: true

require "pg_cron/job"
require "pg_cron/adapters/postgres/query_executor"

module PgCron
  module Adapters
    class Postgres
      # Fetches scheduled jobs from the postgres connection.
      #
      # The F(x) counterpart is Adapters::Postgres::Functions, which reads
      # pg_proc. This reads cron.job — pg_cron's own catalogue.
      #
      # @api private
      class Jobs
        # The query used to retrieve the jobs considered dumpable into
        # `db/schema.rb`.
        #
        # jobname can be NULL: cron.schedule() has an arity that does not take
        # one. Such a job cannot be expressed as create_cron_job, which is keyed
        # by name, so it is excluded rather than dumped wrongly.
        JOBS_WITH_DEFINITIONS_QUERY = <<~SQL.freeze
          SELECT
              jobname,
              schedule,
              command,
              database,
              username,
              active
          FROM cron.job
          WHERE jobname IS NOT NULL
          ORDER BY jobname;
        SQL

        # Wraps #all as a static facade.
        #
        # @return [Array<PgCron::Job>]
        def self.all(connection)
          PgCron::Adapters::Postgres::QueryExecutor.call(
            connection: connection,
            query: JOBS_WITH_DEFINITIONS_QUERY,
            model_class: PgCron::Job
          )
        end
      end
    end
  end
end
