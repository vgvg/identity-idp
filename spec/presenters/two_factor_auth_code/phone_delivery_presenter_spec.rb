require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  include Rails.application.routes.url_helpers

  let(:view) { ActionController::Base.new.view_context }
  let(:data) do
    {
      confirmation_for_phone_change: false,
      confirmation_for_idv: false,
      phone_number: '5555559876',
      code_value: '999999',
      otp_delivery_preference: 'sms',
      reenter_phone_number_path: '/verify/phone',
      unconfirmed_phone: true,
      totp_enabled: false,
      personal_key_unavailable: true,
      reauthn: false,
    }
  end
  let(:data_for_locale) do
    data_for_locale = {}
    I18n.available_locales.each do |locale|
      data_for_locale[locale]=     {
          confirmation_for_phone_change: false,
          confirmation_for_idv: false,
          phone_number: '5555559876',
          code_value: '999999',
          otp_delivery_preference: 'sms',
          reenter_phone_number_path: "#{locale == :en ? nil : '/'+locale.to_s}/verify/phone",
          unconfirmed_phone: true,
          totp_enabled: false,
          personal_key_unavailable: true,
          reauthn: false,
      }
    end
    data_for_locale
  end
  let(:presenter) do
    TwoFactorAuthCode::PhoneDeliveryPresenter.new(
      data: data,
      view: view
    )
  end
  let(:presenter_for_locale) do
    presenter_for_locale = {}
    I18n.available_locales.each do |locale|
      presenter_for_locale[locale]=    TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: data_for_locale[locale],
          view: view,

      )
    end
    presenter_for_locale
  end

  it 'is a subclass of GenericDeliveryPresenter' do
    expect(TwoFactorAuthCode::PhoneDeliveryPresenter.superclass).to(
      be(TwoFactorAuthCode::GenericDeliveryPresenter)
    )
  end

  describe '#cancel_link' do
    it 'returns the sign out path during authentication' do
      expect(presenter.cancel_link).to eq sign_out_path
    end

    it 'returns the account path during reauthn' do
      data[:reauthn] = true
      expect(presenter.cancel_link).to eq account_path
    end

    it 'returns the account path during phone change confirmation' do
      data[:confirmation_for_phone_change] = true
      expect(presenter.cancel_link).to eq account_path
    end

    it 'returns the verification cancel path during identity verification' do
      data[:confirmation_for_idv] = true
      expect(presenter.cancel_link).to eq verify_cancel_path
    end
  end

  describe '#fallback_links' do
    it 'handles multiple locales' do
      I18n.available_locales.each do |locale|
        I18n.locale = locale
        presenter_for_locale[locale].fallback_links.each do |html|
          if locale == :en
            expect(html).not_to match(%r{href="/en/})
          else
            expect(html).to match(%r{href="/#{locale}/})
          end
        end
        if locale == :en
          expect(presenter_for_locale[locale].cancel_link).not_to match(%r{/en/})
        else
          expect(presenter_for_locale[locale].cancel_link).to match(%r{/#{locale}/})
        end
      end
    end

    context 'with totp enabled' do
      before do
        data[:totp_enabled] = true
      end

      context 'voice otp delivery supported' do
        it 'renders an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'renders a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end

      context 'voice otp deliver unsupported' do
        before do
          data[:voice_otp_delivery_unsupported] = true
        end

        it 'renders an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'does not render a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end
    end

    context 'without totp enabled' do
      context 'voice otp delivery supported' do
        it 'does not render an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'renders a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end

      context 'voice otp deliver unsupported' do
        before do
          data[:voice_otp_delivery_unsupported] = true
        end

        it 'does not render an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'does not render a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end
    end
  end
end
