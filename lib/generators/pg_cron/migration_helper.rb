# frozen_string_literal: true

module PgCron
  module Generators
    # Chooses the migration template and filename.
    #
    # Copied from Fx::Generators::MigrationHelper, minus the object_type
    # argument: this gem has one kind of object, so the templates are named
    # create_job / update_job rather than being interpolated per type.
    #
    # @api private
    class MigrationHelper
      def initialize(options)
        @options = options
      end

      def skip_creation?
        !should_create_migration?
      end

      def update_migration_class_name(class_name:, version:)
        "UpdateCronJob#{class_name}ToVersion#{version}"
      end

      def migration_template_info(file_name:, updating_existing:, version:)
        if updating_existing
          {
            template: "db/migrate/update_job.erb",
            filename: "db/migrate/update_cron_job_#{file_name}_to_version_#{version}.rb"
          }
        else
          {
            template: "db/migrate/create_job.erb",
            filename: "db/migrate/create_cron_job_#{file_name}.rb"
          }
        end
      end

      private

      attr_reader :options

      def should_create_migration?
        options.fetch(:migration, true)
      end
    end
  end
end
