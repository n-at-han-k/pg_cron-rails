# frozen_string_literal: true

require "pg_cron_rails/adapters/postgresql_adapter"
require "pg_cron_rails/configuration"
require "pg_cron_rails/definition"
require "pg_cron_rails/job"
require "pg_cron_rails/schema_dumper"
require "pg_cron_rails/statements"
require "pg_cron_rails/command_recorder"
require "pg_cron_rails/railtie" if defined?(::Rails::Railtie)

module PgCronRails
  def self.load
    # Make PgCronRails::Statements available during migrations
    ActiveRecord::ConnectionAdapters::AbstractAdapter.include PgCronRails::Statements

    # Make PgCronRails::Statements reversible for migration rollbacks
    ActiveRecord::Migration::CommandRecorder.include PgCronRails::CommandRecorder

    # Teach the schema dumper about cron jobs. Without this db/schema.rb carries
    # every table and none of the schedules, so a db:schema:load database comes
    # up silently missing them.
    ActiveRecord::SchemaDumper.prepend PgCronRails::SchemaDumper
  end

  def self.connection
    connection = configuration.connection
    connection.reconnect! unless connection.active?
    connection
  end
end
