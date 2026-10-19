# frozen_string_literal: true

require_dependency 'jobs/base'

module Jobs
  # Registers or removes the Bale webhook when the plugin setting changes.
  class SetupBaleWebhook < ::Jobs::Base
    def execute(*)
      if SiteSetting.bale_notifications_enabled?
        setup_webhook
      else
        remove_webhook
      end
    end

    private

    def setup_webhook
      # Keep the existing secret stable across retries.
      secret = SiteSetting.bale_secret
      if secret.blank?
        secret = SecureRandom.hex
        SiteSetting.bale_secret = secret
      end

      response = DiscourseBaleNotifications::BaleNotifier.setup_webhook(secret)
      ensure_successful_response!(
        response,
        'Bale webhook registration failed',
        'Bale webhook registration failed; the current webhook secret was retained'
      )
    end

    def remove_webhook
      response = DiscourseBaleNotifications::BaleNotifier.delete_webhook
      ensure_successful_response!(response, 'Bale webhook removal failed', 'Bale webhook removal failed')
    end

    def ensure_successful_response!(response, error_message, log_message)
      return if response.is_a?(Hash) && response['ok'] == true

      Rails.logger.error(log_message)
      # Raising marks the job as failed so Sidekiq can apply its retry policy.
      raise StandardError, error_message
    end
  end
end
