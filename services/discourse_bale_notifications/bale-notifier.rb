require 'json'
require 'net/http'

module DiscourseBaleNotifications
  class BaleNotifier
    def self.sendMessage(message)
      return self.doRequest('sendMessage', message)
    end

    def self.answerCallback(callback_id, text)
      message = {
        callback_query_id: callback_id,
        text: text
      }
      return self.doRequest('answerCallbackQuery', message)
    end

    def self.setupWebhook(key)
      message = {
        # آدرس وب‌هوک با دامنه بله و مسیر جدید
        url: Discourse.base_url + '/bale/hook/' + SiteSetting.bale_secret,
      }
      return self.doRequest('setWebhook', message)
    end

    # فاز یک - اصلاح #۱۰: برای حذف صریح وب‌هوک از سمت بله هنگام غیرفعال‌سازی
    # افزونه، تا سرور بله برای همیشه تلاش برای تحویل به endpointِ اکنون
    # غیرفعال را متوقف کند.
    def self.deleteWebhook
      return self.doRequest('deleteWebhook', {})
    end

    def self.editKeyboard(message)
      return self.doRequest('editMessageReplyMarkup', message)
    end

    def self.doRequest(methodName, message)
      # تغییر دامنه به سرور بله
      http = Net::HTTP.new("tapi.bale.ai", 443)
      http.use_ssl = true
      # فاز یک - اصلاح #۵: بدون timeout صریح، یک هنگ‌کردن یا کندی سرور بله
      # می‌توانست یک Worker سیدکیک را بی‌نهایت مشغول نگه دارد.
      http.open_timeout = 5
      http.read_timeout = 10

      access_token = SiteSetting.bale_access_token
      # تغییر Base URL به فرمت استاندارد بله
      uri = URI("https://tapi.bale.ai/bot#{access_token}/#{methodName}")

      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = message.to_json

      # شناسه‌ی چت فقط برای لاگ (نه محتوای پیام) استخراج می‌شود.
      chat_id_for_log = message[:chat_id] || message['chat_id']

      begin
        response = http.request(req)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError,
             Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
        Rails.logger.error(
          "Bale API request failed before receiving a response " \
          "(method=#{methodName}, chat_id=#{chat_id_for_log}): #{e.class}: #{e.message}"
        )
        return false
      end

      begin
        responseData = JSON.parse(response.body)
      rescue JSON::ParserError => e
        # فاز یک - اصلاح #۵: پاسخ‌های غیر JSON (مثلاً صفحه‌ی خطای پروکسی هنگام
        # قطعی سرویس بله) قبلاً باعث رها شدن یک Exception بدون rescue می‌شدند.
        Rails.logger.error(
          "Bale API returned a non-JSON response " \
          "(method=#{methodName}, http_status=#{response.code}): #{e.message}"
        )
        return false
      end

      if not responseData['ok'] == true
        # فاز یک - اصلاح #۶: قبلاً کل بدنه‌ی پیام (req.body) که می‌توانست شامل
        # خلاصه‌ی پیام‌های خصوصی کاربران باشد، عیناً در لاگ سرور نوشته می‌شد.
        # اکنون فقط اطلاعات غیرحساس (نام متد، chat_id، وضعیت HTTP، و کد/توضیح
        # خطای خودِ API بله) لاگ می‌شود - نه متن پیام.
        Rails.logger.error(
          "Bale API call failed (method=#{methodName}, chat_id=#{chat_id_for_log}, " \
          "http_status=#{response.code}, error_code=#{responseData['error_code']}, " \
          "description=#{responseData['description']})"
        )

        # فاز دو - اصلاح #۱۴: اگر بله اعلام کند کاربر ربات را بلاک کرده یا چت
        # دیگر معتبر نیست، تلاش مکرر و بی‌نتیجه برای ارسال پیام به آن چت
        # فایده‌ای ندارد؛ اتصال به‌صورت خودکار قطع می‌شود تا هم لاگ تمیز بماند
        # و هم کاربر (در صورت بازگشت) بداند باید دوباره اتصال را برقرار کند.
        unlink_chat_if_unreachable(chat_id_for_log, responseData)

        return false
      end
      return responseData
    end

    # فاز دو - اصلاح #۱۴: خطاهای استاندارد APIهای سازگار با تلگرام برای
    # «ربات بلاک شده» (error_code 403) یا «چت دیگر وجود ندارد» (error_code 400
    # با توضیح «chat not found») را تشخیص می‌دهد.
    def self.bot_unreachable?(responseData)
      code = responseData['error_code']
      description = responseData['description'].to_s
      return true if code == 403
      return true if code == 400 && description.match?(/chat not found/i)
      false
    end

    def self.unlink_chat_if_unreachable(chat_id, responseData)
      return if chat_id.blank?
      return unless bot_unreachable?(responseData)

      removed = UserCustomField.where(name: "bale_chat_id", value: chat_id.to_s).delete_all
      if removed > 0
        Rails.logger.info(
          "Bale notifications: automatically unlinked chat_id=#{chat_id} " \
          "after Bale reported it as blocked/unreachable"
        )
      end
    end

    def self.generateReplyMarkup(post, user)
      likes = UserAction.where(action_type: UserAction::LIKE, user_id: user.id, target_post_id: post.id).count
      if likes > 0
        likeButtonText = I18n.t("discourse_bale_notifications.unlike")
        likeButtonAction = "unlike:#{post.id}"
      else
        likeButtonText = I18n.t("discourse_bale_notifications.like")
        likeButtonAction = "like:#{post.id}"
      end
      
      post_url = "#{Discourse.base_url}#{post.url(opts={without_slug: true})}"
      {
        inline_keyboard: [
          [
            { text: likeButtonText, callback_data: likeButtonAction },
            { text: I18n.t("discourse_bale_notifications.view_online"), url: post_url },
          ]
        ]
      }
    end
  end
end
