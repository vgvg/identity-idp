class CancelActions
  def initialize(current_user:, session:, fallback_cancel_link: nil)
    @current_user = current_user
    @session = session
    @fallback_cancel_link = fallback_cancel_link
  end

  def cancel_action_partial
    if user_signing_up? || user_verifying_identity?
      # doesn't belong here since the cancel partial is used at least during:
      # - sign up
      # - sign in
      # - authentication
      # - profile editing
      # - weird state in which the user hasn't actually created anything,
      #   but still wants to cancel, as in the case of the first screen of
      #   registering, i.e. entering their email. Technically that would warrant
      #   a sign in action, we need to just remove the current session
      'two_factor_authentication/shared/cancel_actions/sign_up_or_verify'
    else
      'two_factor_authentication/shared/cancel_actions/sign_in'
    end
    # weirdly, the existing cancel partial will stay, because there are a ton of
    # places where we pass the cancel link manually to it
    # only the actions change
  end

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_sign_up')
    elsif user_verifying_identity?
      t('links.cancel_verification')
    else
      t('links.cancel')
    end
  end

  def continue_button_text

  end

  def continue_path
    # TODO: this is harder, we need some way to know what the next path is
    # based on the current one...i dont think we have a wizard type
    # state machine currently
  end

  # returns enumerated list of points
  def warning_points
    user_signing_up? ? [] : []
  end

  # is the user submitting pii?
  def user_verifying_identity?
    session[:sp] && session[:sp][:loa3] && current_user.recovery_code.present?
  end

  private

  attr_reader :current_user, :session, :fallback_cancel_link

  def t(translation)
    I18n.t(translation)
  end

  def link_path
    # return whether link returns user to home page signed out or what
    # sign in -- returns user to home screen, logged out
    # sign up -- delete account info
    # verify -- delete pii
    # all of these return to home page
    # obviously with no js, these links just do that action, no modal
    # do we need this right now? also it will be hard to know where to point the user?
    # send(:destroy_user_path), we also need the method....like put or post
    # no both are deletes for now, so this could be ok
    send("#{fallback_cancel_link || destroy_user_session_path}".to_sym)
  end

  # does the user not have an account?
  def user_signing_up?
    session[:registering] || (current_user && !current_user.recovery_code.present?)
  end

end
