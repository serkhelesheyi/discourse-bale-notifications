# frozen_string_literal: true

require_dependency 'jobs/base'

module Jobs
  class SendBaleNotifications < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.bale_notifications_enabled?

      payload = args[:payload]
      notification_type_name = Notification.types[payload[:notification_type]].to_s
      return unless SiteSetting.bale_enabled_notification_types.split('|').include?(notification_type_name)

      user = User.find(args[:user_id])
      chat_id = user.custom_fields['bale_chat_id']

      return if chat_id.nil? || chat_id.empty?

      # فاز سه - اصلاح #۱۸: اگر کاربر خودش ترجیحی برای زیرمجموعه‌ای از انواع
      # ثبت کرده باشد، به آن احترام گذاشته می‌شود. اگر فیلد خالی/تنظیم‌نشده
      # باشد (رفتار پیش‌فرض برای همه‌ی کاربران فعلی)، هیچ محدودیت اضافه‌ای
      # اعمال نمی‌شود - یعنی رفتار قبلی (همه‌ی انواع فعال سایت) دقیقاً حفظ می‌شود.
      user_type_prefs = user.custom_fields['bale_notification_types']
      return if user_type_prefs.present? && !user_type_prefs.split('|').include?(notification_type_name)

      post = Post.where(post_number: payload[:post_number], topic_id: payload[:topic_id]).first

      # فاز دو - اصلاح #۱۳: با وجود ۱۰ فایل ترجمه‌ی موجود در این افزونه، تا
      # پیش از این اصلاح، I18n.t همیشه از زبان پیش‌فرض سایت استفاده می‌کرد
      # (چون در Sidekiq، I18n.locale به‌طور پیش‌فرض روی SiteSetting.default_locale
      # تنظیم می‌شود، مگر صراحتاً override شود) - نه زبانی که خودِ کاربر در
      # پروفایلش انتخاب کرده. این همان الگویی است که خود هسته‌ی دیسکورس هم
      # برای ایمیل‌های اعلان استفاده می‌کند.
      message_text = I18n.with_locale(user.effective_locale) do
        I18n.t(
          "discourse_bale_notifications.message.#{notification_type_name}",
          site_title: CGI.escapeHTML(SiteSetting.title),
          site_url: Discourse.base_url,
          post_url: CGI.escapeHTML(Discourse.base_url + payload[:post_url].to_s),
          post_excerpt: CGI.escapeHTML(payload[:excerpt]),
          topic: CGI.escapeHTML(payload[:topic_title]),
          username: CGI.escapeHTML(payload[:username]),
          user_url: CGI.escapeHTML("#{Discourse.base_url}/u/#{payload[:username]}")
        )
      end

      # فاز سه - اصلاح #۱۷: آواتار کاربر عامل (کسی که اعلان را ایجاد کرده،
      # نه لزوماً گیرنده) برای ارسال احتمالی به‌همراه پیام محاسبه می‌شود.
      # منطق تصمیم‌گیری نهایی (آیا واقعاً به‌صورت عکس ارسال شود) داخل
      # BaleNotifier.sendNotification است.
      acting_user = User.find_by(username: payload[:username])
      avatar_url = "#{Discourse.base_url}#{acting_user.avatar_template.gsub('{size}', '128')}" if acting_user

      # فاز سه - اصلاح #۱۹: «ساعات سکوت» - چیزی حذف/به‌تاخیر نمی‌افتد، فقط
      # با پرچم disable_notification به بله گفته می‌شود پیام را بی‌صدا
      # تحویل دهد. بر اساس منطقه‌ی زمانی خودِ گیرنده (در صورت تنظیم‌بودن در
      # پروفایلش)، وگرنه منطقه‌ی زمانی پیش‌فرض سایت.
      disable_notification = false
      if SiteSetting.bale_notifications_quiet_hours_enabled?
        begin
          zone_name = user.user_option&.timezone.presence || Time.zone.name
          hour = Time.find_zone!(zone_name).now.hour
          start_hour = SiteSetting.bale_notifications_quiet_hours_start
          end_hour = SiteSetting.bale_notifications_quiet_hours_end
          disable_notification =
            if start_hour == end_hour
              false # بازه‌ی صفر یعنی عملاً ساعات سکوتی وجود ندارد
            elsif start_hour < end_hour
              hour >= start_hour && hour < end_hour
            else
              # بازه‌ای که از نیمه‌شب رد می‌شود، مثل ۲۲ تا ۸
              hour >= start_hour || hour < end_hour
            end
        rescue ArgumentError
          # منطقه‌ی زمانی نامعتبر/ناشناس در پروفایل کاربر؛ به‌صورت ایمن
          # نادیده گرفته می‌شود و پیام عادی (با صدا) ارسال می‌شود.
          disable_notification = false
        end
      end

      response = DiscourseBaleNotifications::BaleNotifier.send_notification(
        message_text,
        chat_id,
        DiscourseBaleNotifications::BaleNotifier.generate_reply_markup(post, user),
        avatar_url: avatar_url,
        disable_notification: disable_notification
      )

      return unless response

      message_id = response['result']['message_id']
      # مطابق اصلاح بحرانی #۲: کلید بر اساس chat_id هم namespace شده است.
      PluginStore.set('bale-notifications', "message_#{chat_id}_#{message_id}", post.id)
    end
  end

end
