# frozen_string_literal: true

module DiscourseBaleNotifications
  # Applies a conservative retry policy to explicit send API rejections.
  module RetryableDelivery
    class Error < StandardError; end

    def self.raise_if_retryable_api_failure!(response)
      return unless response.is_a?(Hash) && response['ok'] == false

      error_code = response['error_code']
      return unless error_code.is_a?(Integer)
      return unless error_code == 429 || error_code.between?(500, 599)

      raise Error, "Bale temporarily rejected notification delivery (error_code=#{error_code})"
    end
  end
end
