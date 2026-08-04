# frozen_string_literal: true

module PgCron
  module Generators
    # Works out which version of a definition we are creating.
    #
    # Copied from Fx::Generators::VersionHelper. The scan is over db/cron rather
    # than db/functions, and there is one type instead of two, so
    # definition_for_version takes no `type`.
    #
    # @api private
    class VersionHelper
      def initialize(file_name:, definition_path:)
        @file_name = file_name
        @definition_path = definition_path
      end

      def previous_version
        @previous_version ||= existing_versions.max || 0
      end

      def current_version
        previous_version.next
      end

      def updating_existing?
        previous_version > 0
      end

      def creating_new?
        previous_version == 0
      end

      def definition_for_version(version:)
        PgCron::Definition.job(name: file_name, version: version)
      end

      private

      VERSION_PATTERN = /v(\d+)/
      private_constant :VERSION_PATTERN

      attr_reader :file_name, :definition_path

      def existing_versions
        Dir
          .glob("#{file_name}_v*.sql", base: definition_path)
          .map { |file| file[VERSION_PATTERN, 1].to_i }
          .compact
      end
    end
  end
end
