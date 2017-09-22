require 'login_gov/hostdata'

root = File.expand_path('../../', __FILE__)

LoginGov::Hostdata.in_datacenter do |hostdata|
  hostdata.s3.download_configs(
    '/%<env>s/idp/v1/application.yml' => File.join(root, 'config/application_s3.yml'),
    '/%<env>s/idp/v1/database.yml'    => File.join(root, 'config/database_s3.yml')
  )
end

# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!
