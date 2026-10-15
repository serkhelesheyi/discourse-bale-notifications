# frozen_string_literal: true

module DiscourseBaleNotifications
  class BaleNotifier
    def self.send_message(message)
      do_request('sendMessage', message)
    end

    # فاز سه - اصلاح #۱۷: ارسال عکس (مثلاً آواتار کاربر عامل) به‌همراه کپشن.
    def self.send_photo(message)
      do_request('sendPhoto', message)
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
    def self.send_notification(text, chat_id, reply_markup, avatar_url: nil, disable_notification: false)
      if photo_notification?(text, avatar_url)
        send_photo(photo_payload(text, chat_id, reply_markup, avatar_url, disable_notification))
      else
        send_message(text_payload(text, chat_id, reply_markup, disable_notification))
      end
    end

    def self.photo_notification?(text, avatar_url)
      SiteSetting.bale_notifications_show_avatar? && avatar_url.present? && text.bytesize <= CAPTION_LIMIT
    end

    def self.photo_payload(text, chat_id, reply_markup, avatar_url, disable_notification)
      {
        chat_id: chat_id,
        photo: avatar_url,
        caption: text,
        parse_mode: 'html',
        disable_notification: disable_notification,
        reply_markup: reply_markup
      }
    end

    def self.text_payload(text, chat_id, reply_markup, disable_notification)
      {
        chat_id: chat_id,
        text: text,
        parse_mode: 'html',
        disable_web_page_preview: true,
        disable_notification: disable_notification,
        reply_markup: reply_markup
      }
    end

    def self.answer_callback(callback_id, text)
      message = {
        callback_query_id: callback_id,
        text: text
      }
      do_request('answerCallbackQuery', message)
    end

    def self.setup_webhook(_key)
      message = {
        # آدرس وب‌هوک با دامنه بله و مسیر جدید
        url: "#{Discourse.base_url}/bale/hook/#{SiteSetting.bale_secret}"
      }
      return self.do_request('setWebhook', message)
    end

    # فاز یک - اصلاح #۱۰: برای حذف صریح وب‌هوک از سمت بله هنگام غیرفعال‌سازی
    # افزونه، تا سرور بله برای همیشه تلاش برای تحویل به endpointِ اکنون
    # غیرفعال را متوقف کند.
    def self.delete_webhook
      return self.do_request('deleteWebhook', {})
    end

    # فاز سه - اصلاح #۱۵: برای نمایش وضعیت واقعی وب‌هوک (آیا ثبت شده، آخرین
    # خطا از سمت بله چه بوده) در پنل مدیریتی.
    def self.fetch_webhook_info
      return self.do_request('getWebhookInfo', {})
    end

    def self.edit_keyboard(message)
      return self.do_request('editMessageReplyMarkup', message)
    end

    # فاز سه - اصلاح #۱۵: لاگ فعالیت اخیر برای پنل مدیریتی. عمداً فقط تلاش‌های
    # ارسال واقعی پیام (sendMessage/sendPhoto) ثبت می‌شوند، نه هر فراخوانی
    # داخلی API (مثل answerCallback)، تا این لاگ برای ادمین معنادار بماند.
    def self.recent_activity
      BaleActivityLog.recent_activity
    end

    def self.record_activity(method_name, chat_id, success, error_code, description)
      BaleActivityLog.record_activity(method_name, chat_id, success, error_code, description)
    end

    def self.do_request(method_name, message)
      BaleApiClient.call(method_name, message)
    end

    def self.generate_reply_markup(post, user)
      BaleReplyMarkup.generate(post, user)
    end
  end
end
