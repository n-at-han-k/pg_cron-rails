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

  def self.connection
    connection = configuration.connection
    connection.reconnect! unless connection.active?
    connection
  end
end
