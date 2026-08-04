# frozen_string_literal: true

module PgCron
  # Migration methods for pg_cron schedules, following F(x)'s conventions
  # exactly: a name, an optional `version` naming a file in db/cron, an optional
  # `sql_definition` that takes its place, and `revert_to_version` so a rollback
  # restores the previous definition instead of dropping the job outright.
  #
  # Replaces schedule_pg_cron_job / unschedule_pg_cron_job / update_pg_cron_job,
  # which took only a name and read a YAML file. Those had no versioning, so a
  # changed schedule left no record of what it had been and a rollback could
  # only delete the job.
  module Statements
    # Create a new cron job.
    #
    # @param name [String, Symbol] The job's name. pg_cron keys on jobname, so
    #   this is its identity — scheduling over an existing name replaces it.
    # @param version [Integer] The version number, used to find the definition
    #   file in `db/cron`. Defaults to `1`.
    # @param sql_definition [String] The SQL for the job. An error is raised if
    #   `sql_definition` and `version` are both set, as they are mutually
    #   exclusive.
    # @return [void]
    #
    # @example Create from `db/cron/drain_juicefs_events_v01.sql`
    #   create_cron_job(:drain_juicefs_events, version: 1)
    #
    # @example Create from provided SQL string
    #   create_cron_job(:drain_juicefs_events, sql_definition: <<~SQL)
    #     SELECT cron.schedule(
    #       'drain_juicefs_events',
    #       '* * * * *',
    #       $$SELECT juicefs_index_events(500)$$
    #     );
    #   SQL
    #
    def create_cron_job(name, version: nil, sql_definition: nil, revert_to_version: nil)
      validate_version_and_sql_definition_exclusive!(version, sql_definition)
      version ||= 1

      return unless PgCron.database.pg_cron_enabled?

      PgCron.database.create_job(resolve_sql_definition(sql_definition, name, version))
    end

    # Drop a cron job by name.
    #
    # @param name [String, Symbol] The job's name.
    # @param revert_to_version [Integer] Used to reverse this on
    #   `rake db:rollback`; passed as `version` to {#create_cron_job}.
    # @return [void]
    #
    def drop_cron_job(name, revert_to_version: nil)
      return unless PgCron.database.pg_cron_enabled?

      PgCron.database.drop_job(name)
    end

    # Update a cron job.
    #
    # One statement, not unschedule-then-schedule: cron.schedule() against an
    # existing jobname REPLACES that job. Dropping first would leave a window in
    # which the schedule does not exist, and on a frequently-firing job that
    # window is a missed run.
    #
    # @param name [String, Symbol] The job's name.
    # @param version [Integer] The version number, used to find the definition
    #   file in `db/cron`.
    # @param sql_definition [String] The SQL for the job.
    # @param revert_to_version [Integer] The version to roll back to.
    # @return [void]
    #
    def update_cron_job(name, version: nil, sql_definition: nil, revert_to_version: nil)
      validate_version_or_sql_definition_present!(version, sql_definition)
      validate_version_and_sql_definition_exclusive!(version, sql_definition)

      return unless PgCron.database.pg_cron_enabled?

      PgCron.database.update_job(name, resolve_sql_definition(sql_definition, name, version))
    end

    private

    VERSION_OR_SQL_DEFINITION_REQUIRED = "version or sql_definition must be specified"
    private_constant :VERSION_OR_SQL_DEFINITION_REQUIRED

    VERSION_AND_SQL_DEFINITION_EXCLUSIVE = "sql_definition and version cannot both be set"
    private_constant :VERSION_AND_SQL_DEFINITION_EXCLUSIVE

    def validate_version_or_sql_definition_present!(version, sql_definition)
      raise ArgumentError, VERSION_OR_SQL_DEFINITION_REQUIRED, caller if version.nil? && sql_definition.nil?
    end

    def validate_version_and_sql_definition_exclusive!(version, sql_definition)
      raise ArgumentError, VERSION_AND_SQL_DEFINITION_EXCLUSIVE, caller if version.present? && sql_definition.present?
    end

    def resolve_sql_definition(sql_definition, name, version)
      return sql_definition.strip_heredoc if sql_definition

      PgCron::Definition.job(name: name, version: version).to_sql
    end
  end
end
