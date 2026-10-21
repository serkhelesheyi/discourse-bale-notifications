# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::RetryableWebhookOperation do
  describe '.raise_if_retryable_api_failure!' do
    [429, 500, 502, 503, 599].each do |code|
      it "raises for transient API error code #{code}" do
        response = { 'ok' => false, 'error_code' => code, '_bale_http_status' => 200 }

        expect { described_class.raise_if_retryable_api_failure!(response, 'registration') }
          .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error)
      end
    end

    [429, 500, 502, 503, 599].each do |status|
      it "raises for transient HTTP status #{status}" do
        response = { 'ok' => false, 'error_code' => 400, '_bale_http_status' => status }

        expect { described_class.raise_if_retryable_api_failure!(response, 'removal') }
          .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error)
      end
    end

    [400, 401, 403, 404, 422].each do |code|
      it "does not retry permanent API error code #{code}" do
        response = { 'ok' => false, 'error_code' => code, '_bale_http_status' => 200 }

        expect { described_class.raise_if_retryable_api_failure!(response, 'registration') }.not_to raise_error
      end
    end

    it 'does not retry string or malformed error codes and HTTP statuses' do
      response = { 'ok' => false, 'error_code' => '503', '_bale_http_status' => '503' }

      expect { described_class.raise_if_retryable_api_failure!(response, 'registration') }.not_to raise_error
    end

    it 'retries a known transport failure' do
      response = { 'ok' => false, '_bale_transport_failure' => true }

      expect { described_class.raise_if_retryable_api_failure!(response, 'removal') }
        .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error, /transport layer/)
    end

    it 'does not retry successful or ambiguous responses' do
      [
        { 'ok' => true },
        false,
        nil,
        { 'ok' => false, 'description' => 'no classification metadata' }
      ].each do |response|
        expect { described_class.raise_if_retryable_api_failure!(response, 'registration') }.not_to raise_error
      end
    end
  end
end
