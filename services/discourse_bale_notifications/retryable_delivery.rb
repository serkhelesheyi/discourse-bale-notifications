# frozen_string_literal: true

module DiscourseBaleNotifications
  # Applies a conservative retry policy to explicit send API rejections.
  module RetryableDelivery
    class Error < StandardError; end

    def self.raise_if_retryable_api_failure!(response)
      return unless response.is_a?(Hash) && response['ok'] == false

      error_code = response['error_code']
      http_status = response['_bale_http_status']
      return unless transient_code?(error_code) || transient_code?(http_status)

      details = []
      details << "http_status=#{http_status}" if transient_code?(http_status)
      details << "error_code=#{error_code}" if transient_code?(error_code)
      raise Error, "Bale temporarily rejected notification delivery (#{details.join(', ')})"
    end

    def self.transient_code?(code)
      code.is_a?(Integer) && (code == 429 || code.between?(500, 599))
    end
  end
end
