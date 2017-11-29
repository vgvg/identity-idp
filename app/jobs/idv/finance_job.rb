module Idv
  class FinanceJob < ProoferJob
    def verify_identity_with_vendor
      confirmation = agent.submit_financials(vendor_params, vendor_session_id)
      result = extract_result(confirmation)
      store_result(result)
    end

    private

    def vendor
      Figaro.env.proofing_vendor_finance.to_sym
    end
  end
end
