# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'

module DiscourseBaleNotifications
  # Performs HTTP requests to the Bale Bot API and handles API failures.
  class BaleApiClient
    def self.call(method_name, message)
      # تغییر دامنه به سرور بله
      http = Net::HTTP.new('tapi.bale.ai', 443)
      http.use_ssl = true
      # فاز یک - اصلاح #۵: بدون timeout صریح، یک هنگ‌کردن یا کندی سرور بله
      # می‌توانست یک Worker سیدکیک را بی‌نهایت مشغول نگه دارد.
      http.open_timeout = 5
      http.read_timeout = 10

      access_token = SiteSetting.bale_access_token
      # تغییر Base URL به فرمت استاندارد بله
      uri = URI("https://tapi.bale.ai/bot#{access_token}/#{method_name}")

      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = message.to_json

      # شناسه‌ی چت فقط برای لاگ (نه محتوای پیام) استخراج می‌شود.
      chat_id_for_log = message[:chat_id] || message['chat_id']

      begin
        response = http.request(req)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError,
             Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
        Rails.logger.error(
          'Bale API request failed before receiving a response ' \
          "(method=#{method_name}, chat_id=#{chat_id_for_log}): #{e.class}: #{e.message}"
        )
        BaleActivityLog.record_activity(method_name, chat_id_for_log, false, nil, "#{e.class}: #{e.message}")
        return false
      end

      begin
        response_data = JSON.parse(response.body)
      rescue JSON::ParserError => e
        # فاز یک - اصلاح #۵: پاسخ‌های غیر JSON (مثلاً صفحه‌ی خطای پروکسی هنگام
        # قطعی سرویس بله) قبلاً باعث رها شدن یک Exception بدون rescue می‌شدند.
        Rails.logger.error(
          'Bale API returned a non-JSON response ' \
          "(method=#{method_name}, http_status=#{response.code}): #{e.message}"
        )
        BaleActivityLog.record_activity(method_name, chat_id_for_log, false, response.code, 'non-JSON response')
        return false
      end

      unless response_data['ok'] == true
        # فاز یک - اصلاح #۶: قبلاً کل بدنه‌ی پیام (req.body) که می‌توانست شامل
        # خلاصه‌ی پیام‌های خصوصی کاربران باشد، عیناً در لاگ سرور نوشته می‌شد.
        # اکنون فقط اطلاعات غیرحساس (نام متد، chat_id، وضعیت HTTP، و کد/توضیح
        # خطای خودِ API بله) لاگ می‌شود - نه متن پیام.
        Rails.logger.error(
          "Bale API call failed (method=#{method_name}, chat_id=#{chat_id_for_log}, " \
          "http_status=#{response.code}, error_code=#{response_data['error_code']}, " \
          "description=#{response_data['description']})"
        )

        # فاز دو - اصلاح #۱۴: اگر بله اعلام کند کاربر ربات را بلاک کرده یا چت
        # دیگر معتبر نیست، تلاش مکرر و بی‌نتیجه برای ارسال پیام به آن چت
        # فایده‌ای ندارد؛ اتصال به‌صورت خودکار قطع می‌شود تا هم لاگ تمیز بماند
        # و هم کاربر (در صورت بازگشت) بداند باید دوباره اتصال را برقرار کند.
        unlink_chat_if_unreachable(chat_id_for_log, response_data)
        BaleActivityLog.record_activity(method_name, chat_id_for_log, false, response_data['error_code'], response_data['description'])

        return false
      end

      BaleActivityLog.record_activity(method_name, chat_id_for_log, true, nil, nil)
      response_data
    end

    # فاز دو - اصلاح #۱۴: خطاهای استاندارد APIهای سازگار با تلگرام برای
    # «ربات بلاک شده» (error_code 403) یا «چت دیگر وجود ندارد» (error_code 400
    # با توضیح «chat not found») را تشخیص می‌دهد.
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
