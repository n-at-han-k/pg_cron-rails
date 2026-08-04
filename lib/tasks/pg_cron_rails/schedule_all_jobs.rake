# frozen_string_literal: true

namespace :pg_cron_rails do
  desc "Schedule every job in db/cron at its highest version"
  task schedule_all_jobs: :environment do |_t, _args|
    latest_job_versions.each do |name, version|
      ActiveRecord::Base.connection.create_cron_job(name, version: version)
    end
    puts "All the pg_cron jobs were successfully scheduled"
  rescue StandardError => e
    puts "Something went wrong while scheduling the pg_cron jobs"
    puts e
  end

  private

  # Definitions are db/cron/<name>_v<NN>.sql, so a job with several versions has
  # several files and only the HIGHEST is current. Globbing filenames the way
  # this task did for YAML would schedule every historical version in turn and
  # leave whichever sorted last in place.
  def latest_job_versions
    directory = Rails.root.join("db", PgCronRails::Definition::DIRECTORY)

    Dir.glob("*_v*.sql", base: directory).each_with_object({}) do |file, latest|
      match = file.match(/\A(?<name>.+)_v(?<version>\d+)\.sql\z/)
      next unless match

      name = match[:name]
      version = match[:version].to_i
      latest[name] = version if version > latest.fetch(name, 0)
    end
  end
end
