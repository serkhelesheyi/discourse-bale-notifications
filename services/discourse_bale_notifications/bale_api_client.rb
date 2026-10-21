# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'

module DiscourseBaleNotifications
  # Performs HTTP requests to the Bale Bot API and handles API failures.
  NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Net::HTTPBadResponse,
    SocketError,
    OpenSSL::SSL::SSLError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::EPIPE,
    Errno::ETIMEDOUT,
    EOFError
  ].freeze

  # Sends requests to the Bale Bot API and normalizes responses and failures.
  class BaleApiClient
    def self.call(method_name, message)
      http, request, chat_id = build_request(method_name, message)
      response = perform_request(http, request, method_name, chat_id)
      return false unless response

      response_data = parse_response(response, method_name, chat_id)
      if response_data == :invalid_json
        status = response.code.to_i
        if %w[setWebhook deleteWebhook].include?(method_name) &&
            (status == 429 || status.between?(500, 599))
          return { 'ok' => false, '_bale_http_status' => status }
        end
        return false
      end

      return handle_api_failure(method_name, chat_id, response, response_data) unless response_data['ok'] == true

      BaleActivityLog.record_activity(method_name, chat_id, true, nil, nil)
      response_data
    end

    def self.build_request(method_name, message)
      http = Net::HTTP.new('tapi.bale.ai', 443)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      uri = URI("https://tapi.bale.ai/bot#{SiteSetting.bale_access_token}/#{method_name}")
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = message.to_json
      chat_id = message[:chat_id] || message['chat_id']
      [http, request, chat_id]
    end

    def self.perform_request(http, request, method_name, chat_id)
      http.request(request)
    rescue *DiscourseBaleNotifications::NETWORK_ERRORS => e
      Rails.logger.error(
        'Bale API request failed before receiving a response ' \
        "(method=#{method_name}, error=#{e.class})"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, nil, "network failure (#{e.class})")
      if %w[setWebhook deleteWebhook].include?(method_name)
        { 'ok' => false, '_bale_transport_failure' => true }
      else
        false
      end
    end

    def self.parse_response(response, method_name, chat_id)
      response_data = JSON.parse(response.body)
      return response_data if response_data.is_a?(Hash) && valid_success_response?(method_name, response_data, response)

      log_invalid_response_structure(response, method_name, chat_id)
      :invalid_json
    rescue JSON::ParserError
      log_non_json_response(response, method_name, chat_id)
      :invalid_json
    end

    def self.valid_success_response?(method_name, response_data, response)
      return true unless response_data['ok'] == true
      return false unless response.code.to_i.between?(200, 299)
      return true unless %w[sendMessage sendPhoto].include?(method_name)

      result = response_data['result']
      result.is_a?(Hash) && result['message_id'].present?
    end

    def self.log_invalid_response_structure(response, method_name, chat_id)
      Rails.logger.error(
        'Bale API returned an invalid response ' \
        "(method=#{method_name}, http_status=#{response.code})"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, response.code, 'invalid response')
    end

    def self.log_non_json_response(response, method_name, chat_id)
      Rails.logger.error(
        'Bale API returned a non-JSON response ' \
        "(method=#{method_name}, http_status=#{response.code})"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, response.code, 'non-JSON response')
    end

    def self.handle_api_failure(method_name, chat_id, response, response_data)
      log_api_failure(method_name, response, response_data)
      unlink_chat_if_unreachable(chat_id, response_data)
      BaleActivityLog.record_activity(
        method_name, chat_id, false, response_data['error_code'], activity_error_description(response_data)
      )
      # Preserve only the classification metadata needed by idempotent webhook jobs.
      # Never log or persist the response body, URL, token, or webhook secret.
      if %w[setWebhook deleteWebhook].include?(method_name)
        return response_data.merge('_bale_http_status' => response.code.to_i)
      end

      # Notification delivery has its own retry classifier.
      return response_data if %w[sendMessage sendPhoto].include?(method_name)

      false
    end

    def self.log_api_failure(method_name, response, response_data)
      Rails.logger.error(
        "Bale API call failed (method=#{method_name}, " \
        "http_status=#{response.code}, error_code=#{response_data['error_code']})"
      )
    end

    # Keep arbitrary remote descriptions out of persistent activity and Rails logs.
    # The original response is still returned to the notification job for classification.
    def self.activity_error_description(response_data)
      code = response_data['error_code']
      return 'rate limited by Bale API' if code == 429
      return 'temporary Bale API failure' if code.is_a?(Integer) && code.between?(500, 599)
      return 'chat blocked or unavailable' if bot_unreachable?(response_data)

      'Bale API rejected request'
    end

    def self.bot_unreachable?(response_data)
      code = response_data['error_code']
      description = response_data['description'].to_s
      return true if code == 403
      return true if code == 400 && description.match?(/chat not found/i)

      false
    end

    def self.unlink_chat_if_unreachable(chat_id, response_data)
      return if chat_id.blank?
      return unless bot_unreachable?(response_data)

      removed = UserCustomField.where(name: 'bale_chat_id', value: chat_id.to_s).delete_all
      return unless removed.positive?

      Rails.logger.info(
        'Bale notifications: automatically unlinked an unreachable chat ' \
        'after Bale reported it as blocked/unreachable'
      )
    end
  end
end
