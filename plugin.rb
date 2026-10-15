# frozen_string_literal: true

# name: discourse-bale-notifications
# about: A plugin which posts all user notifications to a bale message
# version: 0.1
# authors: Mohammad Tazari
# url: https://github.com/serkhelesheyi/discourse-bale-notifications
require 'cgi'

enabled_site_setting :bale_notifications_enabled

register_asset 'stylesheets/common.scss'

# فاز سه - اصلاح #۱۵: افزودن لینک پنل مدیریتی به فهرست «Plugins» در ادمین.
add_admin_route 'bale_notifications.title', 'bale-notifications', use_new_show_route: true

after_initialize do
  module ::DiscourseBaleNotifications
    PLUGIN_NAME ||= 'discourse-bale-notifications'
    services_path = "#{Rails.root}/plugins/discourse-bale-notifications/services/discourse_bale_notifications"
    autoload :BaleNotifier, "#{services_path}/bale_notifier"
    autoload :LinkCode, "#{services_path}/link_code"
    autoload :BaleActivityLog, "#{services_path}/bale_activity_log"
    autoload :BaleReplyMarkup, "#{services_path}/bale_reply_markup"
    autoload :BaleApiClient, "#{services_path}/bale_api_client"
    autoload :BaleNotificationPayload, "#{services_path}/bale_notification_payload"
    controllers_path = "#{'#{Rails.root}'}/plugins/discourse-bale-notifications/controllers/discourse_bale_notifications"
    autoload :BaleController, "#{'#{controllers_path}'}/bale_controller"
    autoload :LinkController, "#{'#{controllers_path}'}/link_controller"
    autoload :AdminController, "#{'#{controllers_path}'}/admin_controller"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseBaleNotifications
    end
  end

  DiscourseBaleNotifications::Engine.routes.draw do
    # تغییر مسیر وب‌هوک از /telegram به /bale
    post '/hook/:key' => 'bale#hook'
    # فاز یک - اصلاح #۸: تولید/حذف کد اتصال یک‌بارمصرف (نیازمند ورود به حساب)
    post '/link' => 'link#create'
    delete '/link' => 'link#destroy'
    # فاز سه - اصلاح #۱۵: endpointهای JSON پنل مدیریتی (فقط ادمین)
    get '/admin/status' => 'admin#status'
    post '/admin/test' => 'admin#test'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseBaleNotifications::Engine, at: '/bale'

    scope '/admin/plugins/discourse-bale-notifications',
          constraints: AdminConstraint.new do
      scope format: false do
        get '/bale-notifications' => 'discourse_bale_notifications/admin#index'
      end
    end
  end

  DiscoursePluginRegistry.serialized_current_user_fields << 'bale_chat_id'
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
  DiscoursePluginRegistry.serialized_current_user_fields << 'bale_notification_types'
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

  DiscourseEvent.on(:site_setting_changed) do |name, _old, _new|
    Jobs.enqueue(:setup_bale_webhook) if (name == :bale_notifications_enabled) || (name == :bale_access_token)
  end

  require_dependency 'jobs/base'
  jobs_path = "#{'#{Rails.root}'}/plugins/discourse-bale-notifications/jobs"
  ::Jobs.autoload :SendBaleNotifications, "#{'#{jobs_path}'}/send_bale_notifications"
  ::Jobs.autoload :SetupBaleWebhook, "#{'#{jobs_path}'}/setup_bale_webhook"
end
