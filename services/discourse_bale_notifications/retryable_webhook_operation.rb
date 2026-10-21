# frozen_string_literal: true

module DiscourseBaleNotifications
  # Retries idempotent setWebhook/deleteWebhook operations only when the failure
  # is explicitly transient or the request failed at the transport layer.
  module RetryableWebhookOperation
    class Error < StandardError; end

    TRANSIENT_HTTP_STATUSES = [429, *(500..599)].freeze

    def self.raise_if_retryable_api_failure!(response, operation)
      raise_transport_error!(operation) if transport_failure?(response)

      failure = transient_failure(response)
      raise Error, "Bale webhook #{operation} failed transiently (#{failure})" if failure
    end

    def self.transport_failure?(response)
      response.is_a?(Hash) && response['_bale_transport_failure'] == true
    end
    private_class_method :transport_failure?

    def self.raise_transport_error!(operation)
      raise Error, "Bale webhook #{operation} failed at the transport layer"
    end
    private_class_method :raise_transport_error!

    def self.transient_failure(response)
      return unless response.is_a?(Hash) && response['ok'] == false

      error_code = response['error_code']
      return "error_code=#{error_code}" if transient_code?(error_code)

      http_status = response['_bale_http_status']
      return "http_status=#{http_status}" if transient_code?(http_status)

      nil
    end
    private_class_method :transient_failure

    def self.transient_code?(code)
      code.is_a?(Integer) && TRANSIENT_HTTP_STATUSES.include?(code)
    end
    private_class_method :transient_code?
  end
end
