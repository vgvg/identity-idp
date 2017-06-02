require 'rails_helper'

describe 'reset_password/index.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.passwords.forgot'))
    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content t('headings.passwords.reset')
  end

  it 'includes an option for resetting a password with a personal key' do
    render

    expect(rendered).to have_selector 'button[name="personal_key"][value="true"]'
  end

  it 'includes an option to continue of the user does not have a personal key' do
    render
    expect(rendered).to have_selector 'button[name="personal_key"][value="false"]'
  end
end
