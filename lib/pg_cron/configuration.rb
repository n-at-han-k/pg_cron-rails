# frozen_string_literal: true

module PgCron
  class Configuration
    DEFAULT_PG_DATABASE_NAME = "postgres"
    # Kept for anything still referencing it. PgCron::Definition owns the real
    # path; this is deliberately a literal rather than interpolating
    # Definition::DIRECTORY, so Configuration does not depend on load order —
    # it referenced the constant in its class body and raised NameError at boot
    # whenever Definition happened to be required later.
    JOBS_DIRECTORY = "db/cron"

    # The connection configuration to use when executing pg_cron statements.
    # Defaults to the current connection host and user with default PSQL database.
    attr_writer :connection_config
    attr_reader :connection

    def initialize
      set_connection
    end

    def set_connection
      @connection = PgCron::Adapters::Postgres::Connection.new(
        ActiveRecord::Base.postgresql_connection(@connection_config || default_pg_cron_connection)
      )
    end

    private

    def default_pg_cron_connection
      default_pg_cron_connection = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup
      default_pg_cron_connection[:database] = DEFAULT_PG_DATABASE_NAME
      
      default_pg_cron_connection
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration

    @configuration.set_connection
  end
end
