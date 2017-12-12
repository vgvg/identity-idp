module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('devise.two_factor_authentication.totp_header_text')
    end

    def help_text
      t("instructions.mfa.#{two_factor_authentication_method}.confirm_code_html",
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME),
        tooltip: view.tooltip(t('tooltips.authentication_app')))
    end

    def fallback_links
      [
        otp_fallback_options,
        personal_key_link,
      ].compact
    end

    def cancel_link
      if reauthn
        account_path(locale: LinkLocaleResolver.locale)
      else
        sign_out_path(locale: LinkLocaleResolver.locale)
      end
    end

    private

    attr_reader :user_email, :two_factor_authentication_method

    def otp_fallback_options
      t(
        'devise.two_factor_authentication.totp_fallback.text_html',
        sms_link: sms_link,
        voice_link: voice_link
      )
    end

    def sms_link
      view.link_to(
        t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
        otp_send_path(locale: LinkLocaleResolver.locale, otp_delivery_selection_form: { otp_delivery_preference: 'sms' })
      )
    end

    def voice_link
      view.link_to(
        t('devise.two_factor_authentication.totp_fallback.voice_link_text'),
        otp_send_path(locale: LinkLocaleResolver.locale, otp_delivery_selection_form: { otp_delivery_preference: 'voice' })
      )
    end
  end
end
