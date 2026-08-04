# frozen_string_literal: true

# Definition first: Configuration reads Definition::DIRECTORY in its class body,
# so requiring it later raises NameError at boot.
require "pg_cron/definition"
require "pg_cron/job"
require "pg_cron/adapters/postgres"
require "pg_cron/configuration"
require "pg_cron/schema_dumper"
require "pg_cron/statements"
require "pg_cron/command_recorder"
require "pg_cron/railtie" if defined?(::Rails::Railtie)

module PgCron
  def self.load
    # Make PgCron::Statements available during migrations
    ActiveRecord::ConnectionAdapters::AbstractAdapter.include PgCron::Statements

    # Make PgCron::Statements reversible for migration rollbacks
    ActiveRecord::Migration::CommandRecorder.include PgCron::CommandRecorder

    # Teach the schema dumper about cron jobs. Without this db/schema.rb carries
    # every table and none of the schedules, so a db:schema:load database comes
    # up silently missing them.
    ActiveRecord::SchemaDumper.prepend PgCron::SchemaDumper
  end

  # The adapter cron statements run through.
  #
  # Was a SECOND connection, opened via ActiveRecord::Base.postgresql_connection
  # against a database named `postgres`, and reconnected by hand. Two problems:
  # postgresql_connection was removed in Rails 8, and the separate database was
  # wrong for this setup anyway — cron.job lives in whatever cron.database_name
  # points at, which is the application's own database, so the application's own
  # connection is the one that can see it.
  #
  # It also has to be that connection for a second reason: pg_cron puts
  # row-level security on cron.job filtering by username, so jobs created on a
  # different connection as a different role are invisible to the app and to the
  # schema dumper.
  def self.connection
    configuration.adapter
  end
end
