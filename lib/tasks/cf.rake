namespace :cf do
  desc "Only run on the first application instance"
  task :on_first_instance do
    Kernel.puts "Executing cloud.gov setup..."
    `bin/setup_cloud_dot_gov`
    Kernel.puts "Checking VCAP_APPLICATION status before start..."
    instance_index = JSON.parse(ENV["VCAP_APPLICATION"])["instance_index"] rescue nil
    exit(0) unless instance_index == 0
  end
end