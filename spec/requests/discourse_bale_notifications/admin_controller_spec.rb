# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Bale admin endpoints', type: :request do
  let(:headers) { { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'application/json' } }

  before { SiteSetting.bale_notifications_enabled = true }

  describe 'GET /bale/admin/status' do
    it 'denies a non-admin user' do
      sign_in(Fabricate(:user))

      get '/bale/admin/status', headers: headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'redacts the webhook secret from the status response for an admin' do
      sign_in(Fabricate(:admin))
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:recent_activity).and_return([])
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:fetch_webhook_info).and_return(
        'ok' => true,
        'result' => { 'url' => 'https://example.com/bale/hook?key=secret-key' }
      )

      get '/bale/admin/status', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('webhook_info', 'result', 'url')).to eq(
        'https://example.com/bale/hook?key=[REDACTED]'
      )
      expect(response.body).not_to include('secret-key')
    end

    it 'omits linked chat IDs from the admin activity response' do
      sign_in(Fabricate(:admin))
      linked_user = Fabricate(:user)
      linked_user.custom_fields['bale_chat_id'] = '987654321'
      linked_user.save_custom_fields

      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:recent_activity).and_return(
        [
          {
            'ts' => '2026-10-19T14:00:00Z',
            'method' => 'sendMessage',
            'chat_id' => '987654321',
            'ok' => false,
            'description' => 'temporary API failure'
          }
        ]
      )
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:fetch_webhook_info).and_return(
        'ok' => true,
        'result' => {}
      )

      get '/bale/admin/status', headers: headers

      expect(response).to have_http_status(:ok)
      activity = response.parsed_body.fetch('recent_activity').first
      expect(activity).to include('username' => linked_user.username)
      expect(activity).not_to have_key('chat_id')
      expect(response.body).not_to include('987654321')
    end
  end

  describe 'POST /bale/admin/test' do
    it 'denies a non-admin user before attempting to send a test message' do
      sign_in(Fabricate(:user))
      expect(DiscourseBaleNotifications::BaleNotifier).not_to receive(:send_message)

      post '/bale/admin/test', params: { username: 'target-user' }, headers: headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
# rubocop:enable Metrics/BlockLength
