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
      allow(http).to receive(:request).and_raise(Net::ReadTimeout, 'simulated read timeout')
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('Net::ReadTimeout')
        expect(message).not_to include(access_token, private_message, chat_id.to_s)
      end

      result = described_class.call('sendMessage', chat_id: chat_id, text: private_message)

      expect(result).to be(false)
      expect(DiscourseBaleNotifications::BaleActivityLog).to have_received(:record_activity)
        .with('sendMessage', chat_id, false, nil, a_string_starting_with('Net::ReadTimeout:'))
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

    it 'does not include the token, outgoing message, or chat ID in API error logs' do
      allow(response).to receive(:body).and_return(
        { ok: false, error_code: 500, description: 'simulated API failure' }.to_json
      )
      expect(Rails.logger).to receive(:error) do |message|
        expect(message).to include('simulated API failure')
        expect(message).not_to include(access_token, private_message, chat_id.to_s)
      end
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:record_activity)
        .with('sendMessage', chat_id, false, 500, 'simulated API failure')

      expect(described_class.call('sendMessage', chat_id: chat_id, text: private_message)).to be(false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
