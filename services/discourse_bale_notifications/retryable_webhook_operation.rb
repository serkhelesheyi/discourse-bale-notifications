# frozen_string_literal: true

module DiscourseBaleNotifications
  # Retries idempotent setWebhook/deleteWebhook operations only when the failure
  # is explicitly transient or the request failed at the transport layer.
  module RetryableWebhookOperation
    class Error < StandardError; end

    TRANSIENT_HTTP_STATUSES = [429, *500..599].freeze

    def self.raise_if_retryable_api_failure!(response, operation)
      if response.is_a?(Hash) && response['_bale_transport_failure'] == true
        raise Error, "Bale webhook #{operation} failed at the transport layer"
      end

      return unless response.is_a?(Hash) && response['ok'] == false

      error_code = response['error_code']
      http_status = response['_bale_http_status']
      return unless transient_code?(error_code) || transient_code?(http_status)

      code = transient_code?(error_code) ? "error_code=#{error_code}" : "http_status=#{http_status}"
      raise Error, "Bale webhook #{operation} failed transiently (#{code})"
    end

    def self.transient_code?(code)
      code.is_a?(Integer) && TRANSIENT_HTTP_STATUSES.include?(code)
    end
    private_class_method :transient_code?
  end
end
