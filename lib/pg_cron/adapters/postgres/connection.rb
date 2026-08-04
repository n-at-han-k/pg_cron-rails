# frozen_string_literal: true

require "delegate"

module PgCron
  module Adapters
    class Postgres
      # Decorates an ActiveRecord connection with methods that help determine
      # the connection's capabilities.
      #
      # The F(x) equivalent asks about DROP FUNCTION argument lists. The
      # capability that matters here is whether pg_cron is installed at all:
      # cron.job does not exist until CREATE EXTENSION pg_cron has run, and that
      # additionally requires pg_cron in shared_preload_libraries and a server
      # restart. Every caller checks this first so a migration or a schema dump
      # against a database without cron is a no-op rather than an error.
      #
      # @api private
      class Connection < SimpleDelegator
        def pg_cron_enabled?
          extension_enabled?("pg_cron")
        end
      end
    end
  end
end
