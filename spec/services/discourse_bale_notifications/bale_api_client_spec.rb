# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Grouped API client contract tests share one setup.
RSpec.describe DiscourseBaleNotifications::BaleApiClient do
  let(:access_token) { 'test-bale-token-do-not-log' }
  let(:private_message) { 'private-notification-content-do-not-log' }
  let(:chat_id) { 123_456 }
  let(:http) { double('Net::HTTP') }
  let(:response) { double('HTTP response', code: '200', body: response_body) }
  let(:response_body) { { ok: true, result: { message_id: 7 } }.to_json }

  before do
    allow(SiteSetting).to receive(:bale_access_token).and_return(access_token)
    allow(Net::HTTP).to receive(:new).with('tapi.bale.ai', 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=).with(5)
    allow(http).to receive(:read_timeout=).with(10)
    allow(http).to receive(:request).and_return(response)
    allow(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
  end

  describe '.call' do
    it 'sends JSON over HTTPS with explicit timeouts and records a successful result' do
      result = described_class.call('sendMessage', chat_id: chat_id, text: private_message)

      expect(result).to eq('ok' => true, 'result' => { 'message_id' => 7 })
      expect(http).to have_received(:use_ssl=).with(true)
      expect(http).to have_received(:open_timeout=).with(5)
      expect(http).to have_received(:read_timeout=).with(10)
      expect(http).to have_received(:request) do |request|
        expect(request).to be_a(Net::HTTP::Post)
        expect(request.uri.to_s).to include("/bot#{access_token}/sendMessage")
        expect(request['Content-Type']).to eq('application/json')
        expect(JSON.parse(request.body)).to eq('chat_id' => chat_id, 'text' => private_message)
      end
      expect(DiscourseBaleNotifications::BaleActivityLog).to have_received(:record_activity)
        .with('sendMessage', chat_id, true, nil, nil)
    end

    [
      Errno::ETIMEDOUT,
      Errno::EPIPE,
      Errno::ENETUNREACH,
      EOFError,
      Net::HTTPBadResponse
    ].each do |error_class|
      it "returns false for #{error_class}" do
        allow(http).to receive(:request).and_raise(error_class, 'simulated network failure')
        expect(Rails.logger).to receive(:error) do |message|
          expect(message).to include(error_class.name)
          expect(message).not_to include(access_token, private_message, chat_id.to_s)
        end

        expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
      end
    end

    it 'returns false on network timeout and does not log the token or private message' do
      allow(http).to receive(:request).and_raise(
        Net::ReadTimeout, "simulated timeout with #{access_token} #{private_message} #{chat_id}"
      )
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('Net::ReadTimeout')
        expect(message).not_to include(access_token, private_message, chat_id.to_s)
      end

      result = described_class.call('sendMessage', chat_id: chat_id, text: private_message)

      expect(result).to be(false)
      expect(DiscourseBaleNotifications::BaleActivityLog).to have_received(:record_activity)
        .with('sendMessage', chat_id, false, nil, 'network failure (Net::ReadTimeout)')
    end

    it 'returns false and records a safe diagnostic for a non-JSON response' do
      allow(response).to receive(:body).and_return('<html>gateway error</html>')
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, '200', 'non-JSON response')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end

    it 'returns false and records a safe diagnostic for valid JSON that is not an API response object' do
      allow(response).to receive(:body).and_return('null')
      expect(Rails.logger).to receive(:error).with(
        'Bale API returned an invalid response (method=sendMessage, http_status=200)'
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, '200', 'invalid response')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end

    it 'rejects a JSON object without a boolean API ok field' do
      allow(response).to receive(:body).and_return({ error_code: 503 }.to_json)
      expect(Rails.logger).to receive(:error).with(
        'Bale API returned an invalid response (method=sendMessage, http_status=200)'
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, '200', 'invalid response')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end

    it 'rejects a successful message response without a message ID' do
      allow(response).to receive(:body).and_return({ ok: true, result: {} }.to_json)
      expect(Rails.logger).to receive(:error).with(
        'Bale API returned an invalid response (method=sendMessage, http_status=200)'
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, '200', 'invalid response')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end

    it 'rejects a success-shaped response with a non-success HTTP status' do
      allow(response).to receive(:code).and_return('500')
      allow(response).to receive(:body).and_return(
        { ok: true, result: { message_id: 123 } }.to_json
      )
      expect(Rails.logger).to receive(:error).with(
        'Bale API returned an invalid response (method=sendMessage, http_status=500)'
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, '500', 'invalid response')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end

    it 'redacts arbitrary API descriptions from logs and persisted activity' do
      remote_description = "simulated failure #{access_token} #{private_message} #{chat_id}"
      allow(response).to receive(:body).and_return(
        { ok: false, error_code: 500, description: remote_description }.to_json
      )
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('method=sendMessage', 'http_status=200', 'error_code=500')
        expect(message).not_to include(remote_description, access_token, private_message, chat_id.to_s)
      end
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, 500, 'temporary Bale API failure')

      result = described_class.call('sendMessage', chat_id: chat_id, text: private_message)

      # The caller still receives the original API response for retry/unreachable classification.
      expect(result).to eq(
        'ok' => false,
        'error_code' => 500,
        'description' => remote_description,
        '_bale_http_status' => 200
      )
    end

    [
      {
        method: 'answerCallbackQuery',
        payload: { callback_query_id: 'callback-id', text: 'callback response' },
        chat_id: nil
      },
      {
        method: 'editMessageReplyMarkup',
        payload: { chat_id: 123_456, message_id: 7, reply_markup: {} },
        chat_id: 123_456
      }
    ].each do |scenario|
      it "does not expose retry metadata for a rejected #{scenario[:method]} call" do
        remote_description = "simulated callback failure #{access_token} #{private_message}"
        allow(response).to receive(:body).and_return(
          { ok: false, error_code: 500, description: remote_description }.to_json
        )
        expect(Rails.logger).to receive(:error) do |message|
          expect(message).to include("method=#{scenario[:method]}", 'http_status=200', 'error_code=500')
          expect(message).not_to include(remote_description, access_token, private_message)
        end
        expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
          .with(scenario[:method], scenario[:chat_id], false, 500, 'temporary Bale API failure')

        result = described_class.call(scenario[:method], scenario[:payload])

        # Callback API failures remain best-effort; no retry classification is returned.
        expect(result).to be(false)
      end
    end

    it 'preserves HTTP status for webhook API rejections without logging the response body' do
      allow(response).to receive(:code).and_return('503')
      allow(response).to receive(:body).and_return(
        { ok: false, error_code: 400, description: 'sensitive remote text' }.to_json
      )
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('method=setWebhook', 'http_status=503', 'error_code=400')
        expect(message).not_to include('sensitive remote text', access_token)
      end
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('setWebhook', nil, false, 400, 'Bale API rejected request')

      result = described_class.call('setWebhook', url: 'https://example.com/bale/hook?key=secret')

      expect(result).to eq(
        'ok' => false,
        'error_code' => 400,
        'description' => 'sensitive remote text',
        '_bale_http_status' => 503
      )
    end

    it 'preserves transient HTTP status for a non-JSON webhook response' do
      allow(response).to receive(:code).and_return('503')
      allow(response).to receive(:body).and_return('<html>gateway error</html>')
      expect(Rails.logger).to receive(:error).with(
        'Bale API returned a non-JSON response (method=setWebhook, http_status=503)'
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('setWebhook', nil, false, '503', 'non-JSON response')

      expect(described_class.call('setWebhook', url: 'https://example.com/bale/hook?key=secret')).to eq(
        'ok' => false,
        '_bale_http_status' => 503
      )
    end

    it 'marks webhook transport failures for the retry classifier without exposing request data' do
      allow(http).to receive(:request).and_raise(Net::ReadTimeout, 'simulated transport failure')
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('method=setWebhook', 'Net::ReadTimeout')
        expect(message).not_to include(access_token, 'secret', 'example.com')
      end
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('setWebhook', nil, false, nil, 'network failure (Net::ReadTimeout)')

      result = described_class.call('setWebhook', url: 'https://example.com/bale/hook?key=secret')

      expect(result).to eq('ok' => false, '_bale_transport_failure' => true)
    end

    it 'preserves a transient HTTP status when the API error code looks permanent' do
      allow(response).to receive(:code).and_return('503')
      allow(response).to receive(:body).and_return(
        { ok: false, error_code: 400, description: 'gateway failure' }.to_json
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, 400, 'Bale API rejected request')

      result = described_class.call('sendMessage', chat_id: chat_id, text: private_message)

      expect(result).to eq(
        'ok' => false,
        'error_code' => 400,
        'description' => 'gateway failure',
        '_bale_http_status' => 503
      )
      expect do
        DiscourseBaleNotifications::RetryableDelivery.raise_if_retryable_api_failure!(result)
      end.to raise_error(DiscourseBaleNotifications::RetryableDelivery::Error, /http_status=503/)
    end

    it 'records a generic activity description for a permanent API rejection' do
      allow(response).to receive(:body).and_return(
        { ok: false, error_code: 400, description: 'request may contain private text' }.to_json
      )
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, 400, 'Bale API rejected request')

      described_class.call('sendMessage', chat_id: chat_id, text: private_message)
    end
  end
end
# rubocop:enable Metrics/BlockLength
