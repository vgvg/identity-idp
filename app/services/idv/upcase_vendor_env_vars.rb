module Idv
  class UpcaseVendorEnvVars
    def call
      available_vendors.each do |vendor|
        upcase_env_vars(vendor)
      end
    end

    private

    def available_vendors
      [
        Figaro.env.proofing_vendor_profile,
        Figaro.env.proofing_vendor_finance,
        Figaro.env.proofing_vendor_phone,
      ]
    end

    def upcase_env_vars(vendor)
      ENV.keys.grep(/^#{vendor}_/).each do |env_var_name|
        ENV[env_var_name.upcase] = ENV[env_var_name]
      end
    end
  end
end
