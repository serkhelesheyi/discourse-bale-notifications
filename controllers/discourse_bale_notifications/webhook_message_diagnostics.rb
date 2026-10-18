# frozen_string_literal: true

module DiscourseBaleNotifications
  # Emits opt-in webhook diagnostics without logging message contents or identifiers.
  module WebhookMessageDiagnostics
    def self.log(request_params, incoming)
      return unless SiteSetting.bale_notifications_webhook_diagnostics_enabled

      Rails.logger.info("[BaleNotifications diagnostic] #{details(request_params, incoming).to_json}")
    end

    def self.details(request_params, incoming)
      reply = incoming['reply_to_message']
      message_details(incoming).merge(reply_details(reply)).merge(
        event: 'bale_webhook_message_shape',
        update_keys: keys(request_params)
      )
    end

    def self.message_details(incoming)
      {
        message_keys: keys(incoming),
        text_present: incoming.key?('text'),
        text_type: incoming['text'].class.name
      }
    end

    def self.reply_details(reply)
      reply_is_object = reply.respond_to?(:keys)
      {
        reply_to_message_present: !reply.nil?,
        reply_to_message_type: reply.nil? ? 'nil' : reply.class.name,
        reply_to_message_keys: reply_is_object ? keys(reply) : [],
        reply_message_id_present: reply_is_object && reply['message_id'].present?
      }
    end

    def self.keys(value)
      value.keys.map(&:to_s).sort
    end
  end
end
