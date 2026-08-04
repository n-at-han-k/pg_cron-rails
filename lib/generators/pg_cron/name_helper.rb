# frozen_string_literal: true

module PgCron
  module Generators
    # Formats a job name for use in a generated migration.
    #
    # Copied from Fx::Generators::NameHelper. F(x) quotes names containing a dot
    # because a function or trigger can be schema-qualified; a pg_cron jobname
    # is a plain string in cron.job and never is, but the same rule is kept so a
    # name with a dot still produces valid Ruby rather than a stray constant.
    #
    # @api private
    class NameHelper
      def self.format_for_migration(name)
        if name.include?(".")
          "\"#{name}\""
        else
          ":#{name}"
        end
      end

      def self.validate_and_format(name)
        raise ArgumentError, "Name cannot be blank" if name.blank?

        format_for_migration(name)
      end
    end
  end
end
