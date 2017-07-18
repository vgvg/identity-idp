require 'rails_helper'
require 's3_config_manager'

RSpec.describe S3ConfigManager do
  let(:bucket) { 'example-prod-secrets' }
  let(:env_name_file) { Tempfile.new('test') }
  let(:env_name) { 'staging' }

  before { File.open(env_name_file.path, 'w') { |file| file.puts(env_name) } }
  after { env_name_file.unlink }

  let(:s3_client) { FakeS3.new }
  subject(:s3_config_manager) do
    S3ConfigManager.new(
      bucket: bucket,
      env_name_path: env_name_file.path,
      s3_client: s3_client
    )
  end

  describe '.ec2_metadata' do
    subject(:ec2_metadata) { S3ConfigManager.ec2_metadata }

    let(:metadata) do
      {
        'privateIp' => '172.16.33.170',
        'devpayProductCodes' => nil,
        'availabilityZone' => 'us-west-2b',
        'version' => '2010-08-31',
        'instanceId' => 'i-12345',
        'billingProducts' => nil,
        'instanceType' => 'c3.xlarge',
        'accountId' => '12345',
        'architecture' => 'x86_64',
        'kernelId' => nil,
        'ramdiskId' => nil,
        'imageId' => 'ami-7e22c506',
        'pendingTime' => '2017-08-24T18:10:24Z',
        'region' => 'us-west-2',
      }
    end

    context 'when run in EC2' do
      before do
        stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          to_return(body: metadata.to_json)
      end

      it 'loads metadata' do
        expect(ec2_metadata).to eq(metadata)
      end
    end

    context 'when run outside of EC2' do
      before do
        stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          to_timeout
      end

      it 'returns nil' do
        expect(ec2_metadata).to eq(nil)
      end
    end
  end

  describe '.ec2_metadata_ignore_webmock' do
    subject(:ec2_metadata_ignore_webmock) { S3ConfigManager.ec2_metadata_ignore_webmock }

    it 'returns nil even if webmock prevents HTTP requests' do
      expect(ec2_metadata_ignore_webmock).to eq(nil)
    end
  end

  describe '#download_configs' do
    let(:local_config_file) { Tempfile.new('test') }

    let(:config_files) do
      { '/%<env_name>s/v1/idp/some_config.yml' => local_config_file.path }
    end

    after { local_config_file.unlink }

    subject(:download_configs) { s3_config_manager.download_configs(config_files) }

    context 'when the env file does not exist' do
      before { FileUtils.rm(env_name_file.path) }

      it 'prints an error and does not download anything from s3' do
        expect($stderr).to receive(:puts).
          with("S3ConfigManager: no file exists at #{env_name_file.path}")
        expect(s3_client).to_not receive(:get_object)

        download_configs
      end
    end

    context 'when the env file exists' do
      let(:config_body) { 'test config data' }

      before do
        s3_client.put_object(
          bucket: bucket,
          key: "/#{env_name}/v1/idp/some_config.yml",
          body: config_body
        )
      end

      it 'interpolates filenames, downloads from s3 and writes them to the local path' do
        download_configs

        expect(File.read(local_config_file.path)).to eq(config_body)
      end
    end
  end
end
