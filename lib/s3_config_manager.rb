require 'aws-sdk-core'
require 'json'
require 'net/http'

class S3ConfigManager
  def self.ec2_metadata_ignore_webmock
    errors_to_catch = []

    # in production-like environments, WebMock will not be loaded
    errors_to_catch << WebMock::NetConnectNotAllowedError if defined?(WebMock)

    ec2_metadata
  rescue *errors_to_catch
    nil
  end

  def self.ec2_metadata
    response = ec2_http.get('/2016-09-02/dynamic/instance-identity/document')
    JSON.parse(response.body)
  rescue
    nil
  end

  # @api private
  def self.ec2_http
    http = Net::HTTP.new('169.254.169.254', 80)
    http.read_timeout = 1
    http.continue_timeout = 1
    http.open_timeout = 1
    http
  end

  def initialize(bucket:, env_name_path:, s3_client: nil)
    @bucket = bucket
    @env_name_path = env_name_path
    @s3_client = s3_client
  end

  def download_configs(configs)
    unless File.exist?(env_name_path)
      $stderr.puts "#{self.class}: no file exists at #{env_name_path}"
      return
    end

    configs.each do |s3_path, local_path|
      download_config(s3_path, local_path)
    end
  end

  private

  attr_reader :bucket, :env_name_path

  def env_name
    @env_name ||= File.read(env_name_path).chomp
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def download_config(s3_path, local_path)
    s3_client.get_object(
      bucket: bucket,
      key: format(s3_path, env_name: env_name),
      response_target: local_path
    )
  end
end
