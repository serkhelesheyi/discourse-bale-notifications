# frozen_string_literal: true

module DiscourseBaleNotifications
  # Sends notification messages and delegates transport and payload construction.
  class BaleNotifier
    def self.send_message(message)
      do_request('sendMessage', message)
    end

    # فاز سه - اصلاح #۱۷: ارسال عکس (مثلاً آواتار کاربر عامل) به‌همراه کپشن.
    def self.send_photo(message)
      do_request('sendPhoto', message)
    end

    def self.send_notification(text, chat_id, reply_markup, avatar_url: nil, disable_notification: false)
      if BaleNotificationPayload.photo?(text, avatar_url)
        send_photo(BaleNotificationPayload.photo(text, chat_id, reply_markup, avatar_url, disable_notification))
      else
        send_message(BaleNotificationPayload.text(text, chat_id, reply_markup, disable_notification))
      end
    end

    def self.answer_callback(callback_id, text)
      do_request('answerCallbackQuery', callback_query_id: callback_id, text: text)
    end

    def self.setup_webhook(_key)
      message = {
        # آدرس وب‌هوک با دامنه بله و مسیر جدید
        url: "#{Discourse.base_url}/bale/hook/#{SiteSetting.bale_secret}"
      }
      do_request('setWebhook', message)
    end

    # فاز یک - اصلاح #۱۰: برای حذف صریح وب‌هوک از سمت بله هنگام غیرفعال‌سازی
    # افزونه، تا سرور بله برای همیشه تلاش برای تحویل به endpointِ اکنون
    # غیرفعال را متوقف کند.
    def self.delete_webhook
      do_request('deleteWebhook', {})
    end

    # فاز سه - اصلاح #۱۵: برای نمایش وضعیت واقعی وب‌هوک (آیا ثبت شده، آخرین
    # خطا از سمت بله چه بوده) در پنل مدیریتی.
    def self.fetch_webhook_info
      do_request('getWebhookInfo', {})
    end

    def self.edit_keyboard(message)
      do_request('editMessageReplyMarkup', message)
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
