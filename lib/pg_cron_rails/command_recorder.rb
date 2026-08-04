# frozen_string_literal: true

module PgCronRails
  # Makes the statements reversible, following F(x)'s CommandRecorder.
  #
  # The `revert_to_version` handling is the point. Inverting create_cron_job is
  # a drop, but inverting DROP or UPDATE is only meaningful if the migration
  # said what to go back to — otherwise a rollback either fails or, worse,
  # leaves the job missing. That is why the previous schedule_pg_cron_job /
  # unschedule_pg_cron_job pair could not invert an update at all.
  module CommandRecorder
    def create_cron_job(*args, &block)
      record(:create_cron_job, args, &block)
    end

    def drop_cron_job(*args, &block)
      record(:drop_cron_job, args, &block)
    end

    def update_cron_job(*args, &block)
      record(:update_cron_job, args, &block)
    end

    def invert_create_cron_job(args)
      [:drop_cron_job, args.first]
    end

    def invert_drop_cron_job(args)
      perform_cron_job_inversion(:create_cron_job, args)
    end

    def invert_update_cron_job(args)
      perform_cron_job_inversion(:update_cron_job, args)
    end

    private

    def perform_cron_job_inversion(method, args)
      name, options = args
      options ||= {}

      unless options[:revert_to_version]
        message = "`#{method}` is reversible only if given a `revert_to_version`"
        raise ActiveRecord::IrreversibleMigration, message
      end

      [method, [name, { version: options[:revert_to_version] }]]
    end
  end
end
