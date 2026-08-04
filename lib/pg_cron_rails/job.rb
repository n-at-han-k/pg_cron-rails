# frozen_string_literal: true

module PgCronRails
  # A scheduled job as it exists in cron.job, and how it is written back into
  # db/schema.rb.
  #
  # F(x)'s equivalent is Fx::Function, whose identity is a signature — name plus
  # argument types, because Postgres allows overloads. A cron job has none:
  # pg_cron keys on jobname, so the name is the identity and scheduling over an
  # existing name replaces it.
  #
  # @api private
  class Job
    include Comparable

    attr_reader :name, :schedule, :command, :database, :username, :active

    def initialize(row)
      @name = row.fetch("jobname")
      @schedule = row.fetch("schedule")
      @command = row.fetch("command")
      @database = row.fetch("database", nil)
      @username = row.fetch("username", nil)
      @active = row.fetch("active", nil)
    end

    def <=>(other)
      name <=> other.name
    end

    def ==(other)
      name == other.name && definition == other.definition
    end

    # Rebuilt as a cron.schedule() call rather than dumped verbatim: pg_cron
    # stores the PARTS (jobname, schedule, command) in cron.job and keeps no
    # record of the statement that created them, so there is nothing to quote
    # back. This is the same reason F(x) can use pg_get_functiondef and this
    # cannot.
    #
    # The command is dollar-quoted because any non-trivial SQL command contains
    # quotes of its own. $job$ rather than $$ so a command that itself uses $$
    # (a plpgsql body, say) still nests correctly.
    def definition
      <<~SQL
        SELECT cron.schedule(
            #{quote(name)},
            #{quote(schedule)},
            $job$#{command}$job$
        );
      SQL
    end

    def to_schema
      <<~SCHEMA.indent(2)
        create_cron_job :#{name}, sql_definition: <<-'SQL'
        #{definition.indent(4).rstrip}
        SQL
      SCHEMA
    end

    private

    def quote(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
