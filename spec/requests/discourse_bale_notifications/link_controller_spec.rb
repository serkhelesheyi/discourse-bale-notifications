# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Bale account linking', type: :request do
  let(:user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }

  describe 'POST /bale/link' do
    it 'requires an authenticated user and returns a short-lived one-time code to that user' do
      sign_in(user)

      post '/bale/link'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      body = response.parsed_body
      expect(body).to include('code', 'expires_in')
      expect(body['code']).to match(/\A\d{6}\z/)
      expect(body['expires_in']).to eq(DiscourseBaleNotifications::LinkCode::TTL_SECONDS)
      expect(DiscourseBaleNotifications::LinkCode.consume(body['code'])).to eq(user.id)
      expect(DiscourseBaleNotifications::LinkCode.consume(body['code'])).to be_nil
    end
  end

  describe 'DELETE /bale/link' do
    it 'removes only the current user’s Bale chat link' do
      user.custom_fields['bale_chat_id'] = '111111'
      user.save_custom_fields
      other_user.custom_fields['bale_chat_id'] = '222222'
      other_user.save_custom_fields
      expect(UserCustomField.where(user_id: user.id, name: 'bale_chat_id').pluck(:value)).to eq(['111111'])
      sign_in(user)

      delete '/bale/link'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(UserCustomField.where(user_id: user.id, name: 'bale_chat_id').pluck(:value)).to be_empty
      expect(UserCustomField.where(user_id: other_user.id, name: 'bale_chat_id').pluck(:value)).to eq(['222222'])
    end
  end
end
# rubocop:enable Metrics/BlockLength
