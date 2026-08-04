# frozen_string_literal: true

module PgCron
  # Resolves a job name and version to its definition file.
  #
  # Modelled on F(x)'s Fx::Definition: versioned SQL files, looked up first
  # alongside any engine's migration paths and then in the app's own db/.
  #
  # SQL rather than the YAML this gem used to read. A job's body is a SQL
  # statement either way, so YAML meant a SQL string embedded in a YAML scalar —
  # nothing could syntax-check it, dollar-quoting had to survive two levels of
  # escaping, and the schema dumper could not round-trip it. A .sql file holds
  # the cron.schedule() call verbatim.
  #
  # @api private
  class Definition
    JOB = "job"

    # `db/cron`, singular. F(x) derives its directory from the type
    # ("function" -> db/functions) because it manages two kinds of object; this
    # gem manages one, and "db/jobs" would read like Active Job's queues rather
    # than the database's schedule.
    DIRECTORY = "cron"

    def self.job(name:, version:)
      new(name: name, version: version, type: JOB)
    end

    def initialize(name:, version:, type: JOB)
      @name = name
      @version_number = version.to_i
      @type = type
    end

    def to_sql
      content = File.read(find_file || full_path)
      raise "Define #{type} in #{path} before migrating." if content.empty?

      content
    end

    def full_path
      Rails.root.join(path)
    end

    def path
      @_path ||= File.join("db", DIRECTORY, filename)
    end

    def version
      version_number.to_s.rjust(2, "0")
    end

    private

    attr_reader :name, :version_number, :type

    def filename
      @_filename ||= "#{name}_v#{version}.sql"
    end

    # Engines can ship a db/cron beside their migrations; look there before
    # falling back to the host application's.
    def find_file
      migration_paths.lazy
        .map { |migration_path| File.expand_path(File.join("..", "..", path), migration_path) }
        .find { |definition_path| File.exist?(definition_path) }
    end

    def migration_paths
      Rails.application.config.paths["db/migrate"].expanded
    end
  end
end
