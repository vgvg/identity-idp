require File.expand_path('../../lib/s3_config_manager', __FILE__)

root = File.expand_path('../../', __FILE__)
metadata = S3ConfigManager.ec2_metadata_ignore_webmock

if metadata
  S3ConfigManager.new(
    bucket: "login-gov-app-secrets-#{metadata['region']}-#{metadata['accountId']}",
    env_name_path: '/etc/login.gov/info/env'
  ).download_configs(
    '/%<env_name>s/v1/idp/application.yml' => File.join(root, 'config/application.yml'),
    '/%<env_name>s/v1/idp/database.yml'    => File.join(root, 'config/database.yml')
  )
end

# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!
