# frozen_string_literal: true

module DiscourseBaleNotifications
  class BaleController < ::ApplicationController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME
    skip_before_action :check_xhr, :preload_json, :verify_authenticity_token, :redirect_to_login_if_required

    def hook
      unless SiteSetting.bale_notifications_enabled
        render json: { error: 'not_found' }, status: :not_found
        return
      end

      # توجه (فاز صفر - اصلاح بحرانی #۴):
      # `defined? params['key']` تقریباً همیشه truthy است (چون params['key'] همواره
      # 'تعریف‌شده' محسوب می‌شود، حتی اگر nil باشد)، پس آن بخش عملاً کد مرده بود.
      # مقایسه هم از `==` معمولی (غیر constant-time) به secure_compare تغییر کرد
      # تا در برابر timing attack مقاوم باشد. همچنین صراحتاً بررسی می‌شود که
      # bale_secret خالی نباشد، تا در صورت خالی‌ماندن اتفاقی تنظیمات، هیچ درخواستی
      # (حتی با کلید خالی/نامعتبر) پذیرفته نشود.
      # فاز یک - اصلاح #۷ (بخش اول): محدودسازی نرخ تلاش‌های ناموفق برای حدس
      # سکرت، بر اساس IP. توجه: این محدودکننده فقط در شاخه‌ی «کلید نادرست»
      # مصرف (performed!) می‌شود، پس ترافیک معتبر با کلید درست هرگز محدود
      # نمی‌شود؛ can_perform? هم یک بررسی بدون مصرف (peek) است.
      auth_fail_limiter = RateLimiter.new(nil, "bale-hook-auth-fail-#{request.remote_ip}", 20, 1.minute)
      unless auth_fail_limiter.can_perform?
        render json: { error: 'rate_limited' }, status: :too_many_requests
        return
      end

      key = params['key'].to_s
      secret = SiteSetting.bale_secret.to_s
      if secret.blank? || !ActiveSupport::SecurityUtils.secure_compare(key, secret)
        auth_fail_limiter.performed!(raise_error: false)
        Rails.logger.error("Bale hook called with incorrect key from #{request.remote_ip}")
        render json: { error: 'forbidden' }, status: :forbidden
        return
      end

      # پردازش پیام‌های دریافتی (ساختار JSON بله دقیقاً مشابه تلگرام است)
      if params.key?('message')
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

      elsif params.key?('callback_query')
        callback_payload = params['callback_query']
        unless valid_callback_payload?(callback_payload)
          callback_id = callback_payload['id'] if webhook_object?(callback_payload)
          if callback_id.present?
            DiscourseBaleNotifications::BaleNotifier.answer_callback(
              callback_id,
              I18n.t(
                'discourse_bale_notifications.action-unavailable',
                default: '❌ This action is no longer available.'
              )
            )
          end
          render json: { success: true }
          return
        end

        chat_id = params['callback_query']['message']['chat']['id']
        chat_type = params['callback_query']['message']['chat']['type']
        callback_id = params['callback_query']['id']

        # فاز یک - اصلاح #۹: دفاع در عمق، مشابه بخش پیام‌های معمولی.
        if chat_type.present? && chat_type != 'private'
          render json: { success: true }
          return
        end

        # فاز یک - اصلاح #۷ (بخش دوم): محدودسازی نرخ اقدامات هر چت.
        if rate_limited_chat?(chat_id)
          render json: { success: true }
          return
        end

        # توجه (فاز صفر - اصلاح بحرانی #۳):
        # قبلاً این بلوک هیچ rescue‌ای نداشت: اگر chat_id ناشناس بود
        # (UserCustomField پیدا نمی‌شد) یک NoMethodError روی `.user_id` روی nil،
        # و اگر پست حذف شده بود یک ActiveRecord::RecordNotFound رها می‌شد که
        # هیچ‌کدام گرفته نمی‌شدند => پاسخ ۵۰۰ بدون هیچ پاسخی به بله، و دکمه‌ی
        # کاربر در بله در حالت خطا/بارگذاری می‌ماند. اکنون هر دو حالت با یک
        # پیام قابل‌فهم به کاربر و بازگشت موفق (success: true) به بله مدیریت می‌شوند.
        begin
          user_custom_field = UserCustomField.find_by!(name: 'bale_chat_id', value: chat_id.to_s)
          user = User.find(user_custom_field.user_id)
          data = params['callback_query']['data'].to_s.split(':')
          post = Post.find(data[1])
        rescue ActiveRecord::RecordNotFound
          DiscourseBaleNotifications::BaleNotifier.answer_callback(
            callback_id,
            I18n.t(
              'discourse_bale_notifications.action-unavailable',
              default: '❌ This action is no longer available.'
            )
          )
          render json: { success: true }
          return
        end

        # فاز دو - اصلاح #۱۳: پیام‌های لایک/آنلایک هم با زبان کاربر ساخته می‌شوند.
        string = I18n.with_locale(user.effective_locale) do
          if data[0] == 'like'
            begin
              PostActionCreator.create(user, post, :like)
              I18n.t('discourse_bale_notifications.like-success')
            rescue PostAction::AlreadyActed
              I18n.t('discourse_bale_notifications.already-liked')
            rescue Discourse::InvalidAccess
              I18n.t('discourse_bale_notifications.like-failed')
            end

          elsif data[0] == 'unlike'
            begin
              guardian = Guardian.new(user)
              post_action_type_id = PostActionType.types[:like]
              post_action = user.post_actions.find_by(
                post_id: post.id,
                post_action_type_id: post_action_type_id,
                deleted_at: nil
              )
              raise Discourse::NotFound if post_action.blank?

              guardian.ensure_can_delete!(post_action)
              PostAction.remove_act(user, post, post_action_type_id)
              I18n.t('discourse_bale_notifications.unlike-success')
            rescue Discourse::NotFound, Discourse::InvalidAccess
              I18n.t('discourse_bale_notifications.unlike-failed')
            end
          else
            I18n.t('discourse_bale_notifications.action-unavailable', default: '❌ This action is no longer available.')
          end
        end

        # توجه: قبلاً در شاخه‌ی 'like' این متد یک‌بار اینجا و یک‌بار دوباره
        # بعد از if/elsif فراخوانی می‌شد (فراخوانی دوگانه‌ی answerCallback
        # برای بله)؛ اکنون فقط یک‌بار و به‌صورت یکنواخت برای هر سه حالت
        # (like/unlike/نامعتبر) صدا زده می‌شود.
        DiscourseBaleNotifications::BaleNotifier.answer_callback(callback_id, string)

        message = {
          chat_id: chat_id,
          message_id: params['callback_query']['message']['message_id'],
          reply_markup: DiscourseBaleNotifications::BaleNotifier.generate_reply_markup(post, user)
        }
        DiscourseBaleNotifications::BaleNotifier.edit_keyboard(message)
      end

      # پاسخ موفقیت‌آمیز به سرور بله برای جلوگیری از توقف ارسال وب‌هوک‌ها
      data = { success: true }
      render json: data
    end

    private

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
