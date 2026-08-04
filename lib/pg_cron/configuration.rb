# frozen_string_literal: true

module PgCron
  class Configuration
    # Kept for anything still referencing it. PgCron::Definition owns the real
    # path; a literal rather than an interpolation of Definition::DIRECTORY so
    # this does not depend on require order.
    JOBS_DIRECTORY = "db/cron"

    # The adapter used to run cron statements. Defaults to the Postgres adapter
    # over the application's own connection.
    attr_reader :adapter

    def initialize(adapter: PgCron::Adapters::Postgres.new)
      @adapter = adapter
    end

    attr_writer :adapter

    # Retained so `PgCronRails.connection`-era callers keep working.
    def connection
      adapter
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.database
    configuration.adapter
  end
end
