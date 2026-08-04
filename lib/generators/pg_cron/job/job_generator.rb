# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "generators/pg_cron/version_helper"
require "generators/pg_cron/migration_helper"
require "generators/pg_cron/name_helper"

module PgCron
  module Generators
    # Generates a cron job definition and its migration.
    #
    #   rails generate pg_cron:job drain_juicefs_events
    #
    # Structured exactly as Fx::Generators::FunctionGenerator: the same
    # class_option, the same three phases (directory, definition, migration),
    # and the same versioning behaviour — running it again for an existing job
    # COPIES the previous definition to the next version rather than creating an
    # empty file, so an edit starts from what is currently deployed and the
    # migration it writes is an update with revert_to_version set.
    #
    # @api private
    class JobGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      DEFINITION_PATH = %w[db cron].freeze

      class_option :migration, type: :boolean

      def create_cron_directory
        return if job_definition_path.exist?

        empty_directory(job_definition_path)
      end

      def create_job_definition
        if version_helper.creating_new?
          create_file(definition.path)
        else
          copy_file(previous_definition.full_path, definition.full_path)
        end
      end

      def create_migration_file
        return if migration_helper.skip_creation?

        template_info = migration_helper.migration_template_info(
          file_name: file_name,
          updating_existing: version_helper.updating_existing?,
          version: version_helper.current_version
        )

        migration_template(
          template_info.fetch(:template),
          template_info.fetch(:filename)
        )
      end

      def self.next_migration_number(dir)
        ::ActiveRecord::Generators::Base.next_migration_number(dir)
      end

      no_tasks do
        def previous_version
          version_helper.previous_version
        end

        def version
          version_helper.current_version
        end

        def migration_class_name
          if version_helper.updating_existing?
            migration_helper.update_migration_class_name(
              class_name: class_name,
              version: version
            )
          else
            super
          end
        end

        def formatted_name
          PgCron::Generators::NameHelper.format_for_migration(singular_name)
        end
      end

      private

      def job_definition_path
        @_job_definition_path ||= Rails.root.join(*DEFINITION_PATH)
      end

      def version_helper
        @_version_helper ||= PgCron::Generators::VersionHelper.new(
          file_name: file_name,
          definition_path: job_definition_path
        )
      end

      def migration_helper
        @_migration_helper ||= PgCron::Generators::MigrationHelper.new(options)
      end

      def definition
        version_helper.definition_for_version(version: version)
      end

      def previous_definition
        version_helper.definition_for_version(version: previous_version)
      end
    end
  end
end
