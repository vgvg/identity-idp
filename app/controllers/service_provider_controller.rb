class ServiceProviderController < ApplicationController
  protect_from_forgery with: :null_session
  include SecureHeadersConcern

  before_action :verify_confirmed, if: :loa3?, only: :show
  before_action :apply_secure_headers_override, only: :show

  def show
    
  end

  def update
    authorize do
      if FeatureManagement.use_dashboard_service_providers?
        ServiceProviderUpdater.new.run
      end

      render json: { status: 'If the feature is enabled, service providers have been updated.' }
    end
  end

  private

  def authorize
    if authorization_token == Figaro.env.dashboard_api_token
      yield
    else
      head :unauthorized
    end
  end

  def authorization_token
    request.headers['X-LOGIN-DASHBOARD-TOKEN']
  end
end
