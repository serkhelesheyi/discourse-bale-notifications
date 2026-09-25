require 'json'
require 'net/http'

module DiscourseBaleNotifications
  class BaleNotifier
    def self.sendMessage(message)
      return self.doRequest('sendMessage', message)
    end

    # فاز سه - اصلاح #۱۷: ارسال عکس (مثلاً آواتار کاربر عامل) به‌همراه کپشن.
    def self.sendPhoto(message)
      return self.doRequest('sendPhoto', message)
    end

    # حد مجاز کپشن در APIهای سازگار با تلگرام کوتاه‌تر از حد مجاز متن معمولی
    # است (۱۰۲۴ در برابر ۴۰۹۶ کاراکتر). چون متن پیام ما HTML است، کوتاه‌کردن
    # دستی آن می‌تواند یک تگ را نصفه‌کاره رها کند و HTML را خراب کند. به‌جای
    # کوتاه‌سازی پرخطر، وقتی متن در این محدودیت جا نشود، به‌سادگی به حالت
    # sendMessage معمولی (بدون عکس) برمی‌گردیم - راه‌حلی امن و بدون ریسک خرابی خروجی.
    CAPTION_LIMIT = 1024

    # نقطه‌ی ورود مشترک برای ارسال یک اعلان: اگر نمایش آواتار فعال باشد و
    # avatar_url موجود باشد و متن در محدودیت کپشن جا شود، به‌صورت عکس+کپشن
    # ارسال می‌شود؛ در غیر این‌صورت به روش معمول متنی برمی‌گردد. در هر دو
    # حالت، ساختار پاسخ (شامل message_id) یکسان است، پس بقیه‌ی کد
    # (مثل ذخیره‌سازی برای قابلیت پاسخ) نیازی به تغییر ندارد.
    def self.sendNotification(text, chat_id, reply_markup, avatar_url: nil, disable_notification: false)
      if SiteSetting.bale_notifications_show_avatar? && avatar_url.present? && text.bytesize <= CAPTION_LIMIT
        sendPhoto({
          chat_id: chat_id,
          photo: avatar_url,
          caption: text,
          parse_mode: "html",
          disable_notification: disable_notification,
          reply_markup: reply_markup,
        })
      else
        sendMessage({
          chat_id: chat_id,
          text: text,
          parse_mode: "html",
          disable_web_page_preview: true,
          disable_notification: disable_notification,
          reply_markup: reply_markup,
        })
      end
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

    # فاز سه - اصلاح #۱۵: برای نمایش وضعیت واقعی وب‌هوک (آیا ثبت شده، آخرین
    # خطا از سمت بله چه بوده) در پنل مدیریتی.
    def self.getWebhookInfo
      return self.doRequest('getWebhookInfo', {})
    end

    def self.editKeyboard(message)
      return self.doRequest('editMessageReplyMarkup', message)
    end

    # فاز سه - اصلاح #۱۵: لاگ فعالیت اخیر برای پنل مدیریتی. عمداً فقط تلاش‌های
    # ارسال واقعی پیام (sendMessage/sendPhoto) ثبت می‌شوند، نه هر فراخوانی
    # داخلی API (مثل answerCallback)، تا این لاگ برای ادمین معنادار بماند.
    RECORDABLE_METHODS = %w[sendMessage sendPhoto].freeze
    ACTIVITY_LOG_KEY = "recent-activity"
    ACTIVITY_LOG_MAX_ENTRIES = 50

    def self.recent_activity
      PluginStore.get("bale-notifications", ACTIVITY_LOG_KEY) || []
    end

    def self.record_activity(methodName, chat_id, ok, error_code, description)
      return unless RECORDABLE_METHODS.include?(methodName)

      entry = {
        # ISO8601 UTC به‌جای timestamp خام عددی ذخیره می‌شود تا در نمایش
        # فرانت‌اند نیازی به حدس زدن واحد (ثانیه/میلی‌ثانیه) نباشد و ریسک
        # نمایش اشتباه تاریخ از بین برود.
        "ts" => Time.now.utc.iso8601,
        "method" => methodName,
        "chat_id" => chat_id,
        "ok" => ok,
        "error_code" => error_code,
        "description" => description,
      }

      # DistributedMutex چون چند Worker سیدکیک ممکن است هم‌زمان بخواهند این
      # لیست مشترک را بخوانند-و-بنویسند؛ بدون قفل، آخرین نویسنده می‌توانست
      # نوشته‌ی نویسنده‌ی دیگر را از دست بدهد (race condition کلاسیک read-modify-write).
      DistributedMutex.synchronize("bale-notifications-activity-log") do
        log = PluginStore.get("bale-notifications", ACTIVITY_LOG_KEY) || []
        log = ([entry] + log).first(ACTIVITY_LOG_MAX_ENTRIES)
        PluginStore.set("bale-notifications", ACTIVITY_LOG_KEY, log)
      end
    rescue => e
      # ثبت لاگ فعالیت (یک قابلیت صرفاً تشخیصی) هرگز نباید باعث شکست ارسال
      # واقعی پیام شود؛ به همین دلیل اینجا rescue عمومی توجیه‌پذیر است.
      Rails.logger.warn("Bale notifications: failed to record activity log entry: #{e.class}: #{e.message}")
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
        record_activity(methodName, chat_id_for_log, false, nil, "#{e.class}: #{e.message}")
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
        record_activity(methodName, chat_id_for_log, false, response.code, "non-JSON response")
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
        record_activity(methodName, chat_id_for_log, false, responseData['error_code'], responseData['description'])

        return false
      end

      record_activity(methodName, chat_id_for_log, true, nil, nil)
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
