require "spec_helper"

module PgCron
  RSpec.describe 'Configuration' do
    it "must default using the ActiveRecord::Base.connection user" do
      expect(PgCron.connection.execute("SELECT current_user").first["current_user"]).to eq(ActiveRecord::Base.connection_db_config.configuration_hash[:username])
    end

    it "must default connection to DEFAULT_PG_DATABASE_NAME database" do
      expect(PgCron.connection.execute("SELECT current_database()").first["current_database"]).to eq(PgCron::Configuration::DEFAULT_PG_DATABASE_NAME)
    end

    it "must be possible to change database connection configuration" do
      PgCron.configure do |config|
        config.connection_config = ActiveRecord::Base.connection_db_config.configuration_hash.merge({ database: "dummy_development" })
      end
      expect(PgCron.connection.execute("SELECT current_database()").first["current_database"]).to eq("dummy_development")
    end
  end
end
