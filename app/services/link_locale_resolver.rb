class LinkLocaleResolver
  def self.locale
    I18n.locale == I18n.default_locale ? nil : I18n.locale
  end
end
