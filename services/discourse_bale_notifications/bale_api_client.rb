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
      return false if response_data == :invalid_json

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
        "(method=#{method_name}, chat_id=#{chat_id}): #{e.class}: #{e.message}"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, nil, "#{e.class}: #{e.message}")
      false
    end

    def self.parse_response(response, method_name, chat_id)
      response_data = JSON.parse(response.body)
      return response_data if response_data.is_a?(Hash) && valid_response_structure?(method_name, response_data)

      log_invalid_response_structure(response, method_name, chat_id)
      :invalid_json
    rescue JSON::ParserError => e
      log_non_json_response(response, method_name, chat_id, e)
      :invalid_json
    end

    def self.valid_response_structure?(method_name, response_data)
      return true unless %w[sendMessage sendPhoto].include?(method_name) && response_data['ok'] == true

      result = response_data['result']
      result.is_a?(Hash) && result['message_id'].present?
    end

    def self.log_invalid_response_structure(response, method_name, chat_id)
      Rails.logger.error(
        'Bale API returned a JSON response with an invalid structure ' \
        "(method=#{method_name}, http_status=#{response.code})"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, response.code, 'invalid response structure')
    end

    def self.log_non_json_response(response, method_name, chat_id, error)
      Rails.logger.error(
        'Bale API returned a non-JSON response ' \
        "(method=#{method_name}, http_status=#{response.code}): #{error.message}"
      )
      BaleActivityLog.record_activity(method_name, chat_id, false, response.code, 'non-JSON response')
    end

    def self.handle_api_failure(method_name, chat_id, response, response_data)
      log_api_failure(method_name, chat_id, response, response_data)
      unlink_chat_if_unreachable(chat_id, response_data)
      BaleActivityLog.record_activity(
        method_name,
        chat_id,
        false,
        response_data['error_code'],
        response_data['description']
      )
      false
    end

    def self.log_api_failure(method_name, chat_id, response, response_data)
      Rails.logger.error(
        "Bale API call failed (method=#{method_name}, chat_id=#{chat_id}, " \
        "http_status=#{response.code}, error_code=#{response_data['error_code']}, " \
        "description=#{response_data['description']})"
      )
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
        "Bale notifications: automatically unlinked chat_id=#{chat_id} " \
        'after Bale reported it as blocked/unreachable'
      )
    end
  end
end
