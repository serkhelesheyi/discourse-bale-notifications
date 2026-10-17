# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'rails_helper'

RSpec.describe 'Bale webhook', type: :request do
  before do
    SiteSetting.bale_notifications_enabled = true
    SiteSetting.bale_secret = 'test-webhook-secret'
  end

  describe 'POST /bale/hook/:key' do
    it 'returns JSON with forbidden status for an incorrect secret' do
      post '/bale/hook/wrong-secret', params: { message: {} }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq('error' => 'forbidden')
    end

    it 'rejects requests when the configured webhook secret is blank' do
      SiteSetting.bale_secret = ''

      post '/bale/hook/test-webhook-secret', params: { message: {} }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq('error' => 'forbidden')
    end

    it 'acknowledges a message payload with no chat object without raising' do
      post '/bale/hook/test-webhook-secret', params: { message: { text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges a message payload with no chat ID without raising' do
      post '/bale/hook/test-webhook-secret',
           params: { message: { chat: { type: 'private' }, text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges non-private message payloads without processing them' do
      post '/bale/hook/test-webhook-secret',
           params: { message: { chat: { id: 123, type: 'group' }, text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'answers and acknowledges a callback without a message object' do
      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-1',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook/test-webhook-secret',
           params: { callback_query: { id: 'callback-1', data: 'like:1' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges a callback with malformed action data' do
      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-2',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook/test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-2',
               data: 'like:not-an-id',
               message: {
                 message_id: 10,
                 chat: { id: 123, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end
  end
end

# rubocop:enable Metrics/BlockLength
