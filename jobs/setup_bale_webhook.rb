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
      # Keep the existing secret stable across retries. Rotating it before the API
      # confirms registration can invalidate the currently registered webhook.
      secret = SiteSetting.bale_secret
      if secret.blank?
        secret = SecureRandom.hex
        SiteSetting.bale_secret = secret
      end

      response = DiscourseBaleNotifications::BaleNotifier.setup_webhook(secret)
      return if successful_api_response?(response)

      Rails.logger.error(
        'Bale webhook registration failed; the current webhook secret was retained'
      )
      # Jobs::Base is handled by Sidekiq. Raising allows its retry policy to retry
      # transient API/network failures instead of silently completing the job.
      raise StandardError, 'Bale webhook registration failed'
    end

    def remove_webhook
      response = DiscourseBaleNotifications::BaleNotifier.delete_webhook
      return if successful_api_response?(response)

      Rails.logger.error('Bale webhook removal failed')
      raise StandardError, 'Bale webhook removal failed'
    end

    def successful_api_response?(response)
      response.is_a?(Hash) && response['ok'] == true
    end
  end
end
