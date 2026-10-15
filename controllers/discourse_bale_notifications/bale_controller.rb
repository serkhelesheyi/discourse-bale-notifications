# frozen_string_literal: true

module DiscourseBaleNotifications
  # Authenticates Bale webhooks and dispatches message/callback handlers.
  class BaleController < ::ApplicationController
    include WebhookMessageHandler
    include WebhookCallbackHandler
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME
    skip_before_action :check_xhr, :preload_json, :verify_authenticity_token, :redirect_to_login_if_required

    def hook
      return unless SiteSetting.bale_notifications_enabled
      return unless authenticate_webhook_request

      if params.key?('message')
        handle_message
        return if performed?
      elsif params.key?('callback_query')
        handle_callback_query
        return if performed?
      end

      render json: { success: true }
    end

    private

    def authenticate_webhook_request
      auth_fail_limiter = RateLimiter.new(nil, "bale-hook-auth-fail-#{request.remote_ip}", 20, 1.minute)
      unless auth_fail_limiter.can_perform?
        render json: { error: 'rate_limited' }, status: :too_many_requests
        return false
      end

      key = params['key'].to_s
      secret = SiteSetting.bale_secret.to_s
      return true if secret.present? && ActiveSupport::SecurityUtils.secure_compare(key, secret)

      auth_fail_limiter.performed!(raise_error: false)
      Rails.logger.error("Bale hook called with incorrect key from #{request.remote_ip}")
      render json: { error: 'forbidden' }, status: :forbidden
      false
    end

    # Webhook payloads originate outside the application and may be incomplete
    # or structurally invalid. Validate nested objects before indexing into them.
    def webhook_object?(value)
      value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
    end

    def valid_private_chat?(chat)
      webhook_object?(chat) && chat['id'].present? && chat['type'] == 'private'
    end

    def valid_message_payload?(message)
      return false unless webhook_object?(message)

      valid_private_chat?(message['chat'])
    end

    def valid_callback_payload?(callback)
      return false unless webhook_object?(callback)

      callback_message = callback['message']
      return false unless webhook_object?(callback_message)
      return false unless valid_private_chat?(callback_message['chat'])

      callback['id'].present? &&
        callback_message['message_id'].present? &&
        callback['data'].is_a?(String) &&
        callback['data'].match?(/\A(?:like|unlike):[1-9]\d*\z/)
    end

    # Escape dynamic text before interpolating it into a message sent with
    # parse_mode=HTML. This also handles nil defensively.
    def escape_html(value)
      CGI.escapeHTML(value.to_s)
    end

    # فاز یک - اصلاح #۷: محدودکننده‌ی نرخ اقدامات هر چت (پیام/کلیک دکمه).
    # عمداً روی chat_id محدود می‌شود، نه IP، چون همه‌ی درخواست‌ها از سرور بله
    # با IPهای مشترک می‌آیند و محدودسازی بر اساس IP همه‌ی کاربران را باهم
    # محدود می‌کرد.
    def rate_limited_chat?(chat_id)
      limiter = RateLimiter.new(nil, "bale-hook-chat-#{chat_id}", 20, 1.minute)
      !limiter.performed!(raise_error: false)
    end
  end
end
