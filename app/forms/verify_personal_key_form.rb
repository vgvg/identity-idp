class VerifyPersonalKeyForm
  include ActiveModel::Model
  include PersonalKeyValidator

  validates :personal_key, presence: true
  validate :validate_personal_key

  attr_accessor :personal_key
  attr_reader :user

  def initialize(user:, attrs: {})
    attrs[:personal_key] ||= nil

    @user = user

    super(attrs)

    @personal_key = normalize_personal_key(personal_key)
  end

  def submit(flash)
    if valid?
      flash[:personal_key] = reencrypt_pii
      true
    else
      reset_sensitive_fields
      false
    end
  end

  protected

  def password_reset_profile
    @_password_reset_profile ||= user.decorate.password_reset_profile
  end

  def decrypted_pii
    @_pii ||= password_reset_profile.recover_pii(personal_key)
  end

  def validate_password_reset_profile
    errors.add :base, :no_password_reset_profile unless password_reset_profile
  end

  def validate_personal_key
    return check_personal_key if personal_key_decrypts?
    errors.add :personal_key, :personal_key_incorrect
  end

  def reset_sensitive_fields
    self.personal_key = nil
  end

  def personal_key_decrypts?
    decrypted_pii.present?
  rescue Pii::EncryptionError => _err
    false
  end
end
