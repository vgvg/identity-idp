require 'rails_helper'

include ActionView::Helpers::DateHelper

describe Users::SessionsController, devise: true do
  describe 'GET /users/sign_in' do
    it 'clears the session when user is not yet 2fa-ed' do
      sign_in_before_2fa

      get :new

      expect(controller.current_user).to be nil
    end
  end

  describe 'GET /active' do
    context 'when user is present' do
      before do
        stub_sign_in

        get :active
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'clears the Etag header' do
        expect(response.headers['Etag']).to eq ''
      end

      it 'renders json' do
        expect(response.content_type).to eq('application/json')
      end

      it 'sets the timeout key' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['timeout']).to_not be_nil
      end
    end

    context 'when user is not present' do
      it 'sets live key to false' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end
    end

    context 'when user is present' do
      it 'sets live key to true' do
        stub_sign_in
        session[:session_expires_at] = Time.zone.now + 10
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq true
      end

      it 'respects session_expires_at' do
        stub_sign_in
        session[:session_expires_at] = Time.zone.now - 1
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end

      it 'updates pinged_at session key' do
        stub_sign_in
        now = Time.zone.now
        session[:pinged_at] = now

        Timecop.travel(Time.zone.now + 10)
        get :active
        Timecop.return

        expect(session[:pinged_at]).to_not eq(now)
      end
    end

    it 'does not track analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to_not receive(:track_event)

      get :active
    end
  end

  describe 'GET /timeout' do
    it 'signs the user out' do
      sign_in_as_user

      expect(subject.current_user).to_not be_nil

      get :timeout

      expect(flash[:notice]).to eq t(
        'session_timedout',
        app: APP_NAME,
        minutes: Figaro.env.session_timeout_in_minutes
      )

      expect(subject.current_user).to be_nil
    end

    it 'redirects to the homepage' do
      stub_sign_in

      get :timeout

      expect(response).to redirect_to(root_url)
    end

    it 'tracks the timeout' do
      stub_analytics
      sign_in_as_user

      expect(@analytics).to receive(:track_event).with(Analytics::SESSION_TIMED_OUT)

      get :timeout
    end
  end

  describe 'POST /' do
    it 'tracks the successful authentication for existing user' do
      user = create(:user, :signed_up)

      stub_analytics
      analytics_hash = {
        success: true,
        user_id: user.uuid,
        user_locked_out: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_AND_PASSWORD_AUTH, analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: user.password } }
    end

    it 'tracks the unsuccessful authentication for existing user' do
      user = create(:user, :signed_up)

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_AND_PASSWORD_AUTH, analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: 'invalid_password' } }
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics
      analytics_hash = {
        success: false,
        user_id: 'anonymous-uuid',
        user_locked_out: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_AND_PASSWORD_AUTH, analytics_hash)

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }
    end

    it 'tracks unsuccessful authentication for locked out user' do
      user = create(
        :user,
        :signed_up,
        second_factor_locked_at: Time.zone.now
      )

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: true,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_AND_PASSWORD_AUTH, analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: user.password } }
    end

    context 'LOA1 user' do
      it 'hashes password exactly once, hashes attribute access key exactly once' do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
        encrypted_key_maker = EncryptedKeyMaker.new
        allow(EncryptedKeyMaker).to receive(:new).and_return(encrypted_key_maker)
        user = create(:user, :signed_up)

        expect(UserAccessKey).to receive(:new).exactly(:twice).and_call_original
        expect(encrypted_key_maker).to receive(:unlock).exactly(:twice).and_call_original
        expect(EncryptedAttribute).to receive(:new_user_access_key).exactly(:once).and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end
    end

    context 'LOA3 user' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
      end

      it 'hashes password exactly once, hashes attribute access key exactly once' do
        encrypted_key_maker = EncryptedKeyMaker.new
        allow(EncryptedKeyMaker).to receive(:new).and_return(encrypted_key_maker)
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        expect(UserAccessKey).to receive(:new).exactly(:twice).and_call_original
        expect(encrypted_key_maker).to receive(:unlock).exactly(:twice).and_call_original
        expect(EncryptedAttribute).to receive(:new_user_access_key).exactly(:once).and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end

      it 'caches unverified PII pending confirmation' do
        user = create(:user, :signed_up)
        create(
          :profile,
          deactivation_reason: :verification_pending,
          user: user, pii: { ssn: '1234' }
        )

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to match '1234'
      end

      it 'caches PII in the user session' do
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to match '1234'
      end

      it 'deactivates profile if not de-cryptable' do
        user = create(:user, :signed_up)
        profile = create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })
        profile.update!(encrypted_pii: Base64.strict_encode64('nonsense'))

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::EMAIL_AND_PASSWORD_AUTH, analytics_hash)

        profile_encryption_error = {
          error: 'Unable to parse encrypted payload. ' \
                 '#<TypeError: no implicit conversion of nil into String>',
        }
        expect(@analytics).to receive(:track_event).
          with(Analytics::PROFILE_ENCRYPTION_INVALID, profile_encryption_error)

        post :create, params: { user: { email: user.email, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to be_nil
        expect(profile.reload).to_not be_active
      end
    end

    it 'tracks CSRF errors' do
      user = create(:user, :signed_up)
      stub_analytics
      analytics_hash = { controller: 'users/sessions#create' }
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with(Analytics::INVALID_AUTHENTICITY_TOKEN, analytics_hash)

      post :create, params: { user: { email: user.email, password: user.password } }

      expect(response).to redirect_to new_user_session_url
      expect(flash[:alert]).to eq t('errors.invalid_authenticity_token')
    end
  end

  describe '#new' do
    context 'with fully authenticated user' do
      it 'redirects to the profile page' do
        stub_sign_in
        subject.session[:logged_in] = true
        get :new

        expect(response).to redirect_to account_path
        expect(subject.session[:logged_in]).to be true
      end
    end

    context 'with current user' do
      it 'logs the user out' do
        stub_sign_in_before_2fa
        subject.session[:logged_in] = true
        get :new

        expect(request.path).to eq root_path
        expect(subject.session[:logged_in]).to be_nil
      end
    end

    context 'with a new user' do
      it 'renders the new template' do
        get :new
        expect(response).to render_template(:new)
      end

      it 'tracks page visit and any alert flashes' do
        stub_analytics
        allow(controller).to receive(:flash).and_return(alert: 'hello')
        properties = { flash: 'hello' }

        expect(@analytics).to receive(:track_event).with(Analytics::SIGN_IN_PAGE_VISIT, properties)

        get :new
      end
    end

    context 'with fully authenticated user who has a pending profile' do
      it 'redirects to the verify profile page' do
        profile = create(
          :profile,
          deactivation_reason: :verification_pending,
          phone_confirmed: false,
          pii: { ssn: '6666', dob: '1920-01-01' }
        )
        user = profile.user

        stub_sign_in(user)
        get :new

        expect(response).to redirect_to verify_account_path
      end
    end
  end
end
