# frozen_string_literal: true
# name: discourse-bale-notifications
# about: A plugin which posts all user notifications to a bale message
# version: 0.1
# authors: Mohammad Tazari
# url: https://github.com/serkhelesheyi/discourse-bale-notifications
require 'cgi'

enabled_site_setting :bale_notifications_enabled

register_asset "stylesheets/common.scss"

# فاز سه - اصلاح #۱۵: افزودن لینک پنل مدیریتی به فهرست «Plugins» در ادمین.
add_admin_route "bale_notifications.title", "bale-notifications", use_new_show_route: true

after_initialize do
  module ::DiscourseBaleNotifications
    PLUGIN_NAME ||= "discourse-bale-notifications".freeze
    autoload :BaleNotifier, "#{Rails.root}/plugins/discourse-bale-notifications/services/discourse_bale_notifications/bale-notifier"
    autoload :LinkCode, "#{Rails.root}/plugins/discourse-bale-notifications/services/discourse_bale_notifications/link_code"
    
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseBaleNotifications
    end
  end

  DiscourseBaleNotifications::Engine.routes.draw do
    # تغییر مسیر وب‌هوک از /telegram به /bale
    post "/hook/:key" => "bale#hook"
    # فاز یک - اصلاح #۸: تولید/حذف کد اتصال یک‌بارمصرف (نیازمند ورود به حساب)
    post "/link" => "link#create"
    delete "/link" => "link#destroy"
    # فاز سه - اصلاح #۱۵: endpointهای JSON پنل مدیریتی (فقط ادمین)
    get "/admin/status" => "admin#status"
    post "/admin/test" => "admin#test"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseBaleNotifications::Engine, at: "/bale"
  end

  class DiscourseBaleNotifications::BaleController < ::ApplicationController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME
    skip_before_action :check_xhr, :preload_json, :verify_authenticity_token, :redirect_to_login_if_required

    def hook
      if not SiteSetting.bale_notifications_enabled
        render status: 404
        return
      end

      # توجه (فاز صفر - اصلاح بحرانی #۴):
      # `defined? params['key']` تقریباً همیشه truthy است (چون params['key'] همواره
      # "تعریف‌شده" محسوب می‌شود، حتی اگر nil باشد)، پس آن بخش عملاً کد مرده بود.
      # مقایسه هم از `==` معمولی (غیر constant-time) به secure_compare تغییر کرد
      # تا در برابر timing attack مقاوم باشد. همچنین صراحتاً بررسی می‌شود که
      # bale_secret خالی نباشد، تا در صورت خالی‌ماندن اتفاقی تنظیمات، هیچ درخواستی
      # (حتی با کلید خالی/نامعتبر) پذیرفته نشود.
      # فاز یک - اصلاح #۷ (بخش اول): محدودسازی نرخ تلاش‌های ناموفق برای حدس
      # سکرت، بر اساس IP. توجه: این محدودکننده فقط در شاخه‌ی «کلید نادرست»
      # مصرف (performed!) می‌شود، پس ترافیک معتبر با کلید درست هرگز محدود
      # نمی‌شود؛ can_perform? هم یک بررسی بدون مصرف (peek) است.
      auth_fail_limiter = RateLimiter.new(nil, "bale-hook-auth-fail-#{request.remote_ip}", 20, 1.minute)
      if !auth_fail_limiter.can_perform?
        render status: 429
        return
      end

      key = params['key'].to_s
      secret = SiteSetting.bale_secret.to_s
      if secret.blank? || !ActiveSupport::SecurityUtils.secure_compare(key, secret)
        auth_fail_limiter.performed!(raise_error: false)
        Rails.logger.error("Bale hook called with incorrect key from #{request.remote_ip}")
        render status: 403
        return
      end

      # پردازش پیام‌های دریافتی (ساختار JSON بله دقیقاً مشابه تلگرام است)
      if params.key?('message')
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
          user_custom_field = UserCustomField.find_by(name: "bale_chat_id", value: chat_id.to_s)
          user = User.find(user_custom_field.user_id)
          # فاز دو - اصلاح #۱۳: پیام با زبان انتخابی خودِ کاربر ساخته می‌شود،
          # نه لزوماً زبان پیش‌فرض سایت.
          message_text = I18n.with_locale(user.effective_locale) do
            I18n.t(
              "discourse_bale_notifications.known-user",
              site_title: CGI::escapeHTML(SiteSetting.title),
              username: user.username
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
            linked_user.custom_fields["bale_chat_id"] = chat_id.to_s
            linked_user.save_custom_fields
            user = linked_user
            known_user = true
            # فاز دو - اصلاح #۱۳: مطابق بالا.
            message_text = I18n.with_locale(linked_user.effective_locale) do
              I18n.t(
                "discourse_bale_notifications.link-success",
                site_title: CGI::escapeHTML(SiteSetting.title),
                username: linked_user.username
              )
            end
          else
            # اینجا هنوز کاربری شناخته نشده، پس زبان پیش‌فرض سایت به‌کار
            # می‌رود (رفتار طبیعی بدون with_locale).
            message_text = I18n.t(
              "discourse_bale_notifications.initial-contact",
              site_title: CGI::escapeHTML(SiteSetting.title)
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
            post_id = PluginStore.get("bale-notifications", "message_#{chat_id}_#{reply_to_message_id}")
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
                reply_to_post_number: reply_to.post_number,
              }
              manager = NewPostManager.new(user, new_post)
              result = manager.perform

              if result.errors.any?
                errors = result.errors.full_messages.join("\n")
                I18n.t("discourse_bale_notifications.reply-failed", errors: errors)
              else
                I18n.t("discourse_bale_notifications.reply-success", post_url: result.post.full_url)
              end
            else
              I18n.t("discourse_bale_notifications.reply-error")
            end
          end
        end

        message = {
          chat_id: chat_id,
          text: message_text,
          parse_mode: "html",
          disable_web_page_preview: true,
        }
        DiscourseBaleNotifications::BaleNotifier.sendMessage(message)

      elsif params.key?('callback_query')
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
          user_custom_field = UserCustomField.find_by!(name: "bale_chat_id", value: chat_id.to_s)
          user = User.find(user_custom_field.user_id)
          data = params['callback_query']['data'].to_s.split(":")
          post = Post.find(data[1])
        rescue ActiveRecord::RecordNotFound
          DiscourseBaleNotifications::BaleNotifier.answerCallback(
            callback_id,
            I18n.t(
              "discourse_bale_notifications.action-unavailable",
              default: "❌ This action is no longer available."
            )
          )
          render json: { success: true }
          return
        end

        # فاز دو - اصلاح #۱۳: پیام‌های لایک/آنلایک هم با زبان کاربر ساخته می‌شوند.
        string = I18n.with_locale(user.effective_locale) do
          if data[0] == "like"
            begin
              PostActionCreator.create(user, post, :like)
              I18n.t("discourse_bale_notifications.like-success")
            rescue PostAction::AlreadyActed
              I18n.t("discourse_bale_notifications.already-liked")
            rescue Discourse::InvalidAccess
              I18n.t("discourse_bale_notifications.like-fail")
            end

          elsif data[0] == 'unlike'
            begin
              guardian = Guardian.new(user)
              post_action_type_id = PostActionType.types[:like]
              post_action = user.post_actions.find_by(post_id: post.id, post_action_type_id: post_action_type_id, deleted_at: nil)
              raise Discourse::NotFound if post_action.blank?
              guardian.ensure_can_delete!(post_action)
              PostAction.remove_act(user, post, post_action_type_id)
              I18n.t("discourse_bale_notifications.unlike-success")
            rescue Discourse::NotFound, Discourse::InvalidAccess
              I18n.t("discourse_bale_notifications.unlike-failed")
            end
          else
            I18n.t("discourse_bale_notifications.error-unknown-action")
          end
        end

        # توجه: قبلاً در شاخه‌ی "like" این متد یک‌بار اینجا و یک‌بار دوباره
        # بعد از if/elsif فراخوانی می‌شد (فراخوانی دوگانه‌ی answerCallback
        # برای بله)؛ اکنون فقط یک‌بار و به‌صورت یکنواخت برای هر سه حالت
        # (like/unlike/نامعتبر) صدا زده می‌شود.
        DiscourseBaleNotifications::BaleNotifier.answerCallback(callback_id, string)

        message = {
          chat_id: chat_id,
          message_id: params['callback_query']['message']['message_id'],
          reply_markup: DiscourseBaleNotifications::BaleNotifier.generateReplyMarkup(post, user)
        }
        DiscourseBaleNotifications::BaleNotifier.editKeyboard(message)
      end

      # پاسخ موفقیت‌آمیز به سرور بله برای جلوگیری از توقف ارسال وب‌هوک‌ها
      data = { success: true }
      render json: data
    end

    private

    # فاز یک - اصلاح #۷: محدودکننده‌ی نرخ اقدامات هر چت (پیام/کلیک دکمه).
    # عمداً روی chat_id محدود می‌شود، نه IP، چون همه‌ی درخواست‌ها از سرور بله
    # با IPهای مشترک می‌آیند و محدودسازی بر اساس IP همه‌ی کاربران را باهم
    # محدود می‌کرد.
    def rate_limited_chat?(chat_id)
      limiter = RateLimiter.new(nil, "bale-hook-chat-#{chat_id}", 20, 1.minute)
      !limiter.performed!(raise_error: false)
    end
  end

  # فاز یک - اصلاح #۸: کنترلر جداگانه برای اقدامات نیازمند ورود به حساب
  # دیسکورس (تولید/حذف کد اتصال). برخلاف BaleController که یک وب‌هوک عمومی
  # است، این کنترلر از رفتار پیش‌فرض احراز هویت دیسکورس استفاده می‌کند.
  class DiscourseBaleNotifications::LinkController < ::ApplicationController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME
    before_action :ensure_logged_in

    def create
      RateLimiter.new(current_user, "bale-link-code-generate", 5, 10.minutes).performed!
      code = DiscourseBaleNotifications::LinkCode.generate_for(current_user)
      render json: { code: code, expires_in: DiscourseBaleNotifications::LinkCode::TTL_SECONDS }
    rescue RateLimiter::LimitExceeded => e
      render_json_error(e.description, status: 429)
    end

    def destroy
      UserCustomField.where(user_id: current_user.id, name: "bale_chat_id").delete_all
      render json: success_json
    end
  end

  # فاز سه - اصلاح #۱۵: کنترلر پنل وضعیت مدیریتی. فقط برای ادمین (از طریق
  # کلاس پایه‌ی استاندارد Admin::AdminController که بررسی ادمین‌بودن را خودش
  # انجام می‌دهد، دقیقاً مثل بقیه‌ی صفحات /admin/* در دیسکورس).
  class DiscourseBaleNotifications::AdminController < ::Admin::AdminController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME

    def status
      linked_count = UserCustomField.where(name: "bale_chat_id").count
      activity = DiscourseBaleNotifications::BaleNotifier.recent_activity

      chat_ids = activity.map { |entry| entry["chat_id"] }.compact.map(&:to_s).uniq
      usernames_by_chat_id =
        if chat_ids.present?
          UserCustomField
            .joins("INNER JOIN users ON users.id = user_custom_fields.user_id")
            .where(name: "bale_chat_id", value: chat_ids)
            .pluck("user_custom_fields.value", "users.username")
            .to_h
        else
          {}
        end

      activity_with_usernames = activity.map do |entry|
        entry.merge("username" => usernames_by_chat_id[entry["chat_id"].to_s])
      end

      # فراخوانی زنده‌ی getWebhookInfo تا ادمین وضعیت واقعی سمت بله را ببیند،
      # نه فقط آن‌چه در دیتابیس محلی داریم.
      webhook_info = DiscourseBaleNotifications::BaleNotifier.getWebhookInfo

      render json: {
        enabled: SiteSetting.bale_notifications_enabled?,
        linked_users_count: linked_count,
        recent_activity: activity_with_usernames,
        webhook_info: webhook_info,
      }
    end

    def test
      username = params[:username].to_s.strip
      target_user = username.present? ? User.find_by(username: username) : nil

      if target_user.nil?
        return render_json_error(I18n.t("discourse_bale_notifications.admin.user_not_found"), status: 404)
      end

      chat_id = target_user.custom_fields["bale_chat_id"]
      if chat_id.blank?
        return render_json_error(I18n.t("discourse_bale_notifications.admin.user_not_linked"), status: 422)
      end

      test_text = I18n.with_locale(target_user.effective_locale) do
        I18n.t("discourse_bale_notifications.admin.test_message", site_title: CGI::escapeHTML(SiteSetting.title))
      end

      response = DiscourseBaleNotifications::BaleNotifier.sendMessage({
        chat_id: chat_id,
        text: test_text,
        parse_mode: "html",
      })

      if response
        render json: success_json
      else
        render_json_error(I18n.t("discourse_bale_notifications.admin.test_failed"), status: 502)
      end
    end
  end

  DiscoursePluginRegistry.serialized_current_user_fields << "bale_chat_id"
  User.register_custom_field_type('bale_chat_id', :text)
  # توجه (فاز یک - اصلاح #۸): این فیلد دیگر مستقیماً توسط کاربر از طریق API
  # به‌روزرسانی پروفایل قابل‌نوشتن نیست (خط register_editable_user_custom_field
  # حذف شد). مقداردهی آن اکنون فقط از مسیر تایید دوطرفه‌ی کد اتصال (بالا) یا
  # از طریق LinkController#destroy برای حذف اتصال انجام می‌شود.

  # فاز سه - اصلاح #۱۸: ترجیح شخصی هر کاربر از میان انواعی که سایت اصلاً فعال
  # کرده (bale_enabled_notification_types سقف/فهرست مجاز است؛ این فیلد یک
  # زیرمجموعه‌ی اختیاری از همان فهرست برای هر کاربر مشخص می‌کند). برخلاف
  # bale_chat_id، این فیلد صرفاً یک سلیقه‌ی شخصی است، نه یک باند امنیتی، پس
  # مشکلی ندارد که مستقیماً توسط خودِ کاربر قابل‌ویرایش باشد.
  DiscoursePluginRegistry.serialized_current_user_fields << "bale_notification_types"
  User.register_custom_field_type('bale_notification_types', :text)
  register_editable_user_custom_field :bale_notification_types

  # توجه (فاز صفر - اصلاح بحرانی #۱):
  # رویداد `:post_notification_alert` از نسخه 3.2.0.beta1 دیسکورس منسوخ (deprecated)
  # اعلام شده و قرار است کاملاً حذف شود. جایگزین رسمی آن `:push_notification` است
  # که با همان امضا (user, payload) و همان ساختار payload فراخوانی می‌شود.
  # تفاوت رفتاری آگاهانه: بر خلاف رویداد قبلی، `:push_notification` وقتی کاربر
  # در حالت «مزاحم نشوید» (Do Not Disturb) باشد trigger نمی‌شود - این رفتار عمداً
  # حفظ شده چون با انتظار منطقی کاربر از یک اعلان push همخوانی دارد.
  DiscourseEvent.on(:push_notification) do |user, payload|
    if SiteSetting.bale_notifications_enabled?
      Jobs.enqueue(:send_bale_notifications, user_id: user.id, payload: payload)
    end
  end

  DiscourseEvent.on(:site_setting_changed) do |name, old, new|
    if (name == :bale_notifications_enabled) || (name == :bale_access_token)
      Jobs.enqueue(:setup_bale_webhook)
    end
  end

  require_dependency "jobs/base"
  module ::Jobs
    class SendBaleNotifications < ::Jobs::Base
      def execute(args)
        return if !SiteSetting.bale_notifications_enabled?
        
        payload = args[:payload]
        notification_type_name = Notification.types[payload[:notification_type]].to_s
        return unless SiteSetting.bale_enabled_notification_types.split("|").include?(notification_type_name)
        
        user = User.find(args[:user_id])
        chat_id = user.custom_fields["bale_chat_id"]
        
        if (not chat_id.present?) || (chat_id.length < 1)
          return
        end

        # فاز سه - اصلاح #۱۸: اگر کاربر خودش ترجیحی برای زیرمجموعه‌ای از انواع
        # ثبت کرده باشد، به آن احترام گذاشته می‌شود. اگر فیلد خالی/تنظیم‌نشده
        # باشد (رفتار پیش‌فرض برای همه‌ی کاربران فعلی)، هیچ محدودیت اضافه‌ای
        # اعمال نمی‌شود - یعنی رفتار قبلی (همه‌ی انواع فعال سایت) دقیقاً حفظ می‌شود.
        user_type_prefs = user.custom_fields["bale_notification_types"]
        if user_type_prefs.present?
          return unless user_type_prefs.split("|").include?(notification_type_name)
        end
        
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
            site_title: CGI::escapeHTML(SiteSetting.title),
            site_url: Discourse.base_url,
            post_url: Discourse.base_url + payload[:post_url],
            post_excerpt: CGI::escapeHTML(payload[:excerpt]),
            topic: CGI::escapeHTML(payload[:topic_title]),
            username: CGI::escapeHTML(payload[:username]),
            user_url: Discourse.base_url + "/u/" + payload[:username]
          )
        end

        # فاز سه - اصلاح #۱۷: آواتار کاربر عامل (کسی که اعلان را ایجاد کرده،
        # نه لزوماً گیرنده) برای ارسال احتمالی به‌همراه پیام محاسبه می‌شود.
        # منطق تصمیم‌گیری نهایی (آیا واقعاً به‌صورت عکس ارسال شود) داخل
        # BaleNotifier.sendNotification است.
        acting_user = User.find_by(username: payload[:username])
        avatar_url =
          if acting_user
            Discourse.base_url + acting_user.avatar_template.gsub("{size}", "128")
          end

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
        
        response = DiscourseBaleNotifications::BaleNotifier.sendNotification(
          message_text,
          chat_id,
          DiscourseBaleNotifications::BaleNotifier.generateReplyMarkup(post, user),
          avatar_url: avatar_url,
          disable_notification: disable_notification
        )
        
        if response
          message_id = response['result']['message_id']
          # مطابق اصلاح بحرانی #۲: کلید بر اساس chat_id هم namespace شده است.
          PluginStore.set("bale-notifications", "message_#{chat_id}_#{message_id}", post.id)
        end
      end
    end

    class SetupBaleWebhook < ::Jobs::Base
      def execute(args)
        if SiteSetting.bale_notifications_enabled?
          SiteSetting.bale_secret = SecureRandom.hex
          DiscourseBaleNotifications::BaleNotifier.setupWebhook(SiteSetting.bale_secret)
        else
          # فاز یک - اصلاح #۱۰: قبلاً هنگام غیرفعال‌سازی افزونه هیچ اقدامی
          # انجام نمی‌شد و وب‌هوک نزد بله ثبت‌شده باقی می‌ماند؛ بله تا ابد
          # سعی در ارسال درخواست به endpointِ اکنون ۴۰۴ می‌کرد. اکنون هنگام
          # غیرفعال‌سازی، وب‌هوک صراحتاً از سمت بله حذف می‌شود.
          DiscourseBaleNotifications::BaleNotifier.deleteWebhook
        end
      end
    end
  end
end
