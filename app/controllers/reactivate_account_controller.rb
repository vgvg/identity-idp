class ReactivateAccountController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def index
    user_session[:acknowledge_personal_key] ||= true
  end
end
