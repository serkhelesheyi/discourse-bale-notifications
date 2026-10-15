# frozen_string_literal: true

module DiscourseBaleNotifications
  # Handles valid private-chat text messages received by the Bale webhook.
  module WebhookMessageHandler
    def handle_message
      unless valid_message_payload?(params['message'])
        render json: { success: true }
        return
      end

      chat_id = params['message']['chat']['id']
      chat_type = params['message']['chat']['type']

      # فاز یک - اصلاح #۹: دفاع در عمق در برابر گروه‌ها/کانال‌ها. حتی اگر
      # ادمین طبق توصیه‌ی README دستور /setjoingroups را نزده باشد، پیام‌های
      # غیرخصوصی به‌صورت برنامه‌نویسی‌شده و بی‌صدا نادیده گرفته می‌شوند
      # (نه فقط یک توصیه‌ی بیرونی در مستندات).
      if chat_type.present? && chat_type != 'private'
        render json: { success: true }
        return
      end

      # فاز یک - اصلاح #۷ (بخش دوم): محدودسازی نرخ اقدامات هر چت، تا حتی در
      # صورت درز سکرت، یک چت نتواند حجم زیادی از پاسخ/عملیات ایجاد کند.
      if rate_limited_chat?(chat_id)
        render json: { success: true }
        return
      end

      known_user = false

      begin
        user_custom_field = UserCustomField.find_by(name: 'bale_chat_id', value: chat_id.to_s)
        user = User.find(user_custom_field.user_id)
        # فاز دو - اصلاح #۱۳: پیام با زبان انتخابی خودِ کاربر ساخته می‌شود،
        # نه لزوماً زبان پیش‌فرض سایت.
        message_text = I18n.with_locale(user.effective_locale) do
          I18n.t(
            'discourse_bale_notifications.known-user',
            site_title: CGI.escapeHTML(SiteSetting.title),
            username: escape_html(user.username)
          )
        end
        known_user = true
      rescue Discourse::NotFound, NoMethodError
        # فاز یک - اصلاح #۸: به‌جای اتکای مستقیم و یک‌طرفه به chat_id خام
        # (که کاربر آن را دستی در پروفایل کپی می‌کرد)، اتصال اکنون نیازمند
        # یک کد یک‌بارمصرف کوتاه‌مدت است که فقط از داخل تنظیمات کاربری
        # دیسکورس (پس از ورود به حساب) قابل دریافت است. این یعنی برای
        # اتصال موفق، هم باید به حساب دیسکورس دسترسی داشت و هم به همین چت
        # بله - نه فقط دانستن یک عدد.
        incoming_text = params['message']['text'].to_s.strip
        linked_user_id = DiscourseBaleNotifications::LinkCode.consume(incoming_text)
        linked_user = linked_user_id ? User.find_by(id: linked_user_id) : nil

        if linked_user
          linked_user.custom_fields['bale_chat_id'] = chat_id.to_s
          linked_user.save_custom_fields
          user = linked_user
          known_user = true
          # فاز دو - اصلاح #۱۳: مطابق بالا.
          message_text = I18n.with_locale(linked_user.effective_locale) do
            I18n.t(
              'discourse_bale_notifications.link-success',
              site_title: CGI.escapeHTML(SiteSetting.title),
              username: escape_html(linked_user.username)
            )
          end
        else
          # اینجا هنوز کاربری شناخته نشده، پس زبان پیش‌فرض سایت به‌کار
          # می‌رود (رفتار طبیعی بدون with_locale).
          message_text = I18n.t(
            'discourse_bale_notifications.initial-contact',
            site_title: CGI.escapeHTML(SiteSetting.title)
          )
        end
      end

      if known_user && params['message'].key?('reply_to_message')
        begin
          reply_to_message_id = params['message']['reply_to_message']['message_id']
          # توجه (فاز صفر - اصلاح بحرانی #۲):
          # message_id در APIهای سازگار با تلگرام/بله فقط در محدوده‌ی هر چت
          # یکتاست، نه به‌صورت سراسری. کلید ذخیره‌سازی باید حتماً با chat_id
          # namespace شود، وگرنه پیام شماره N در چت یک کاربر با پیام شماره N
          # در چت کاربر دیگر تصادم می‌کند و ممکن است پاسخ روی پست اشتباه پست شود.
          post_id = PluginStore.get('bale-notifications', "message_#{chat_id}_#{reply_to_message_id}")
          reply_to = Post.find(post_id)
          found_post = true
        rescue ActiveRecord::RecordNotFound
          found_post = false
        end

        # فاز دو - اصلاح #۱۳: پیام‌های نتیجه‌ی پاسخ هم با زبان کاربر ساخته می‌شوند.
        message_text = I18n.with_locale(user.effective_locale) do
          if found_post
            new_post = {
              raw: params['message']['text'],
              topic_id: reply_to.topic_id,
              reply_to_post_number: reply_to.post_number
            }
            manager = NewPostManager.new(user, new_post)
            result = manager.perform

            if result.errors.any?
              # Validation messages may include user-controlled input; the
              # translated reply-failed template is sent with parse_mode=HTML.
              errors = escape_html(result.errors.full_messages.join("\n"))
              I18n.t('discourse_bale_notifications.reply-failed', errors: errors)
            else
              I18n.t('discourse_bale_notifications.reply-success', post_url: CGI.escapeHTML(result.post.full_url))
            end
          else
            I18n.t('discourse_bale_notifications.reply-error')
          end
        end
      end

      message = {
        chat_id: chat_id,
        text: message_text,
        parse_mode: 'html',
        disable_web_page_preview: true
      }
      DiscourseBaleNotifications::BaleNotifier.send_message(message)
    end
  end
end
