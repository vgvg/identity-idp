require 'capybara/rspec'
require 'capybara-screenshot/rspec'
# require 'capybara/poltergeist'
require 'rack_session_access/capybara'
require 'selenium/webdriver'

# Capybara.javascript_driver = :poltergeist

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

Capybara.register_driver :headless_chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: { args: %w(headless disable-gpu) }
  )

  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    desired_capabilities: capabilities
end

Capybara.javascript_driver = :headless_chrome

Capybara.default_max_wait_time = 5
Capybara::Screenshot.autosave_on_failure = false
Capybara.asset_host = ENV['RAILS_ASSET_HOST'] || 'http://localhost:3000'
