# frozen_string_literal: true
# name: discourse-bale-notifications
# about: A plugin which posts all user notifications to a bale message
# version: 0.1
# authors: Mohammad Tazari
# url: https://github.com/serkhelesheyi/discourse-bale-notifications
require 'cgi'

enabled_site_setting :bale_notifications_enabled

after_initialize do
  module ::DiscourseBaleNotifications
    PLUGIN_NAME ||= "discourse-bale-notifications".freeze
    autoload :BaleNotifier, "#{Rails.root}/plugins/discourse-bale-notifications/services/discourse_bale_notifications/bale-notifier"
    
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseBaleNotifications
    end
  end

  DiscourseBaleNotifications::Engine.routes.draw do
    # تغییر مسیر وب‌هوک از /telegram به /bale
    post "/hook/:key" => "bale#hook"
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
      key = params['key'].to_s
      secret = SiteSetting.bale_secret.to_s
      if secret.blank? || !ActiveSupport::SecurityUtils.secure_compare(key, secret)
        Rails.logger.error("Bale hook called with incorrect key")
        render status: 403
        return
      end

      # پردازش پیام‌های دریافتی (ساختار JSON بله دقیقاً مشابه تلگرام است)
      if params.key?('message')
        chat_id = params['message']['chat']['id']
        known_user = false
        
        begin
          user_custom_field = UserCustomField.find_by(name: "bale_chat_id", value: chat_id)
          user = User.find(user_custom_field.user_id)
          message_text = I18n.t(
            "discourse_bale_notifications.known-user",
            site_title: CGI::escapeHTML(SiteSetting.title),
            username: user.username
          )
          known_user = true
        rescue Discourse::NotFound, NoMethodError
          message_text = I18n.t(
            "discourse_bale_notifications.initial-contact",
            site_title: CGI::escapeHTML(SiteSetting.title),
            chat_id: chat_id,
          )
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
              message_text = I18n.t(
                "discourse_bale_notifications.reply-failed",
                errors: errors
              )
            else
              message_text = I18n.t(
                "discourse_bale_notifications.reply-success",
                post_url: result.post.full_url
              )
            end
          else
            message_text = I18n.t("discourse_bale_notifications.reply-error")
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
        callback_id = params['callback_query']['id']

        # توجه (فاز صفر - اصلاح بحرانی #۳):
        # قبلاً این بلوک هیچ rescue‌ای نداشت: اگر chat_id ناشناس بود
        # (UserCustomField پیدا نمی‌شد) یک NoMethodError روی `.user_id` روی nil،
        # و اگر پست حذف شده بود یک ActiveRecord::RecordNotFound رها می‌شد که
        # هیچ‌کدام گرفته نمی‌شدند => پاسخ ۵۰۰ بدون هیچ پاسخی به بله، و دکمه‌ی
        # کاربر در بله در حالت خطا/بارگذاری می‌ماند. اکنون هر دو حالت با یک
        # پیام قابل‌فهم به کاربر و بازگشت موفق (success: true) به بله مدیریت می‌شوند.
        begin
          user_custom_field = UserCustomField.find_by!(name: "bale_chat_id", value: chat_id)
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

        string = I18n.t("discourse_bale_notifications.error-unknown-action")

        if data[0] == "like"
          begin
            PostActionCreator.create(user, post, :like)
            string = I18n.t("discourse_bale_notifications.like-success")
          rescue PostAction::AlreadyActed
            string = I18n.t("discourse_bale_notifications.already-liked")
          rescue Discourse::InvalidAccess
            string = I18n.t("discourse_bale_notifications.like-fail")
          end

        elsif data[0] == 'unlike'
          begin
            guardian = Guardian.new(user)
            post_action_type_id = PostActionType.types[:like]
            post_action = user.post_actions.find_by(post_id: post.id, post_action_type_id: post_action_type_id, deleted_at: nil)
            raise Discourse::NotFound if post_action.blank?
            guardian.ensure_can_delete!(post_action)
            PostAction.remove_act(user, post, post_action_type_id)
            string = I18n.t("discourse_bale_notifications.unlike-success")
          rescue Discourse::NotFound, Discourse::InvalidAccess
            string = I18n.t("discourse_bale_notifications.unlike-failed")
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
  end

  DiscoursePluginRegistry.serialized_current_user_fields << "bale_chat_id"
  User.register_custom_field_type('bale_chat_id', :text)
  register_editable_user_custom_field :bale_chat_id

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
        return unless SiteSetting.bale_enabled_notification_types.split("|").include?(Notification.types[payload[:notification_type]].to_s)
        
        user = User.find(args[:user_id])
        chat_id = user.custom_fields["bale_chat_id"]
        
        if (not chat_id.present?) || (chat_id.length < 1)
          return
        end
        
        post = Post.where(post_number: payload[:post_number], topic_id: payload[:topic_id]).first
        
        message_text = I18n.t(
          "discourse_bale_notifications.message.#{Notification.types[payload[:notification_type]]}",
          site_title: CGI::escapeHTML(SiteSetting.title),
          site_url: Discourse.base_url,
          post_url: Discourse.base_url + payload[:post_url],
          post_excerpt: CGI::escapeHTML(payload[:excerpt]),
          topic: CGI::escapeHTML(payload[:topic_title]),
          username: CGI::escapeHTML(payload[:username]),
          user_url: Discourse.base_url + "/u/" + payload[:username]
        )
        
        message = {
          chat_id: chat_id,
          text: message_text,
          parse_mode: "html",
          disable_web_page_preview: true,
          reply_markup: DiscourseBaleNotifications::BaleNotifier.generateReplyMarkup(post, user),
        }
        
        response = DiscourseBaleNotifications::BaleNotifier.sendMessage(message)
        
        if response
          message_id = response['result']['message_id']
          # مطابق اصلاح بحرانی #۲: کلید بر اساس chat_id هم namespace شده است.
          PluginStore.set("bale-notifications", "message_#{chat_id}_#{message_id}", post.id)
        end
      end
    end

    class SetupBaleWebhook < ::Jobs::Base
      def execute(args)
        return if !SiteSetting.bale_notifications_enabled?
        
        SiteSetting.bale_secret = SecureRandom.hex
        DiscourseBaleNotifications::BaleNotifier.setupWebhook(SiteSetting.bale_secret)
      end
    end
  end
end
