class UsersController < ApplicationController
  def destroy
    current_user.destroy! unless current_user.nil?

    flash[:success] = t('loa1.cancel.success')
    redirect_to root_path
  end
end
