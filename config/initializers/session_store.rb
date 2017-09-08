require 'session_encryptor'

# cloud.gov redis compatibility
if ENV['VCAP_SERVICES']
  services = JSON.parse(ENV['VCAP_SERVICES'])
  credentials = services['redis32'].first['credentials']
  redis_url = "redis://:#{credentials['password']}@#{credentials['hostname']}:#{credentials['port']}"
else
  redis_url = Figaro.env.redis_url
end

options = {
  key: '_upaya_session',
  redis: {
    driver: :hiredis,

    # cookie expires with browser close
    expire_after: nil,

    # Redis expires session after N minutes
    ttl: Figaro.env.session_timeout_in_minutes.to_i.minutes,

    key_prefix: "#{Figaro.env.domain_name}:session:",
    url: redis_url,
  },
  serializer: SessionEncryptor.new,
}

Rails.application.config.session_store :redis_session_store, options
