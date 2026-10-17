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
        'result' => { 'url' => 'https://example.com/bale/hook/secret-key' }
      )

      get '/bale/admin/status', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('webhook_info', 'result', 'url')).to eq(
        'https://example.com/bale/hook/[REDACTED]'
      )
      expect(response.body).not_to include('secret-key')
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
