# frozen_string_literal: true

require_dependency 'jobs/base'

module Jobs
  # Registers or removes the Bale webhook when the plugin setting changes.
  class SetupBaleWebhook < ::Jobs::Base
    # Keep retries bounded and consistent for registration/removal operations.
    sidekiq_options retry: 5

    def execute(*)
      if SiteSetting.bale_notifications_enabled?
        setup_webhook
      else
        remove_webhook
      end
    end

    private

    def setup_webhook
      response = DiscourseBaleNotifications::BaleNotifier.setup_webhook(webhook_secret)
      ensure_successful_response!(
        response,
        'registration',
        'Bale webhook registration failed; the current webhook secret was retained'
      )
    end

    def webhook_secret
      return SiteSetting.bale_secret if SiteSetting.bale_secret.present?

      secret = SecureRandom.hex
      SiteSetting.bale_secret = secret
      secret
    end

    def remove_webhook
      response = DiscourseBaleNotifications::BaleNotifier.delete_webhook
      ensure_successful_response!(response, 'removal', 'Bale webhook removal failed')
    end

    def ensure_successful_response!(response, operation, log_message)
      return if response.is_a?(Hash) && response['ok'] == true

      # Only transient API rejections and known transport failures should enter
      # Sidekiq's bounded retry cycle. Permanent API errors are logged safely
      # and stop here instead of being retried pointlessly.
      DiscourseBaleNotifications::RetryableWebhookOperation.raise_if_retryable_api_failure!(
        response,
        operation
      )
      Rails.logger.error(log_message)
    end
  end
end
