# frozen_string_literal: true

require "rails/railtie"

module PgCron
  class Railtie < ::Rails::Railtie
    railtie_name :pg_cron

    initializer "pg_cron.load" do
      ActiveSupport.on_load :active_record do
        PgCron.load
      end
    end

    rake_tasks do
      path = File.expand_path("..", __dir__)
      Dir.glob("#{path}/tasks/**/*.rake").each do |task|
        load task
      end
    end
  end
end
