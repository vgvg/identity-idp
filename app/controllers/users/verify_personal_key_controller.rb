module Users
  class VerifyPersonalKeyController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def new
      flash[:notice] = t('notices.password_reset')
      @personal_key_form = VerifyPersonalKeyForm.new(user: current_user)
    end

    def create
    end
  end
end
