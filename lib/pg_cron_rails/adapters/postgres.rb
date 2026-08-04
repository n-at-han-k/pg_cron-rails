# frozen_string_literal: true

require "pg_cron_rails/adapters/postgres/connection"
require "pg_cron_rails/adapters/postgres/jobs"

module PgCronRails
  # Database adapters.
  #
  # Ships with a Postgres adapter only — pg_cron is a Postgres extension, so
  # there is no other engine to support — but the interface is the same one F(x)
  # defines, so an alternative could be substituted the same way.
  module Adapters
    # The Postgres adapter.
    #
    # @param [#connection] connectable An object that returns the connection to
    #   use. Defaults to `ActiveRecord::Base`.
    #
    # @example
    #  PgCronRails.configure do |config|
    #    config.adapter = PgCronRails::Adapters::Postgres.new
    #  end
    class Postgres
      def initialize(connectable = ActiveRecord::Base)
        @connectable = connectable
      end

      # Every scheduled job in the database.
      #
      # Used by {PgCronRails::SchemaDumper} to populate `schema.rb`. Returns
      # nothing when pg_cron is not installed, because cron.job does not exist
      # then and a schema dump must not fail on a database that simply has no
      # cron.
      #
      # @return [Array<PgCronRails::Job>]
      def jobs
        return [] unless connection.pg_cron_enabled?

        PgCronRails::Adapters::Postgres::Jobs.all(connection)
      end

      # Creates a job in the database.
      #
      # The definition is executed AS GIVEN — it is the cron.schedule() call from
      # db/cron/<name>_v01.sql, so the schedule, the command and any quoting are
      # that file's business. This neither parses nor rewrites it, which is the
      # substantive difference from assembling SQL by interpolating values: a
      # name or command containing a quote produced broken SQL that way.
      #
      # @param sql_definition [String] The SQL for the job.
      # @return [void]
      def create_job(sql_definition)
        execute(sql_definition)
      end

      # Updates a job in the database.
      #
      # NOT drop-then-create, which is what F(x) does for a function: pg_cron's
      # cron.schedule() against an existing jobname REPLACES that job, so the
      # update is a single statement. Dropping first would leave a window with
      # no schedule, and on a frequently-firing job that window is a missed run.
      #
      # The existence check is deliberate — cron.schedule() would otherwise
      # silently CREATE a job that was expected to be there, hiding a migration
      # applied out of order.
      #
      # @param name [String, Symbol] The name of the job.
      # @param sql_definition [String] The SQL for the job.
      # @return [void]
      def update_job(name, sql_definition)
        connection.transaction do
          unless job_exists?(name)
            raise PG::InternalError, "ERROR: could not find valid entry for job '#{name}'"
          end

          execute(sql_definition)
        end
      end

      # Drops the job from the database.
      #
      # @param name [String, Symbol] The name of the job to drop.
      # @return [void]
      def drop_job(name)
        execute("SELECT cron.unschedule(#{quoted(name)});")
      end

      private

      attr_reader :connectable

      delegate :execute, to: :connection

      def connection
        PgCronRails::Adapters::Postgres::Connection.new(connectable.connection)
      end

      def job_exists?(name)
        execute("SELECT 1 FROM cron.job WHERE jobname = #{quoted(name)}").any?
      end

      def quoted(name)
        "'#{name.to_s.gsub("'", "''")}'"
      end
    end
  end
end
