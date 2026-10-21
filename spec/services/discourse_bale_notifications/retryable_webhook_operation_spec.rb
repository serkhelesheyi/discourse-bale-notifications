# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Table-driven retry classification examples share one context.
RSpec.describe DiscourseBaleNotifications::RetryableWebhookOperation do
  describe '.raise_if_retryable_api_failure!' do
    [{ kind: 'API error code', key: 'error_code', operation: 'registration' },
     { kind: 'HTTP status', key: '_bale_http_status', operation: 'removal' }].each do |scenario|
      [429, 500, 502, 503, 599].each do |code|
        it "raises for transient #{scenario[:kind]} #{code}" do
          response = { 'ok' => false, 'error_code' => 400, '_bale_http_status' => 200 }
          response[scenario[:key]] = code

          expect { described_class.raise_if_retryable_api_failure!(response, scenario[:operation]) }
            .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error)
        end
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
# rubocop:enable Metrics/BlockLength
