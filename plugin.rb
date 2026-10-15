# frozen_string_literal: true

# name: discourse-bale-notifications
# about: A plugin which posts all user notifications to a bale message
# version: 0.1
# authors: Mohammad Tazari
# url: https://github.com/serkhelesheyi/discourse-bale-notifications
require 'cgi'

# Namespace and stable plugin identifier for the plugin's Rails engine and services.
module DiscourseBaleNotifications
  PLUGIN_NAME = 'discourse-bale-notifications'
end

enabled_site_setting :bale_notifications_enabled

register_asset 'stylesheets/common.scss'

# فاز سه - اصلاح #۱۵: افزودن لینک پنل مدیریتی به فهرست «Plugins» در ادمین.
add_admin_route 'bale_notifications.title', 'bale-notifications', use_new_show_route: true

after_initialize do
  module ::DiscourseBaleNotifications
    services_path = "#{Rails.root}/plugins/discourse-bale-notifications/services/discourse_bale_notifications"
    autoload :BaleNotifier, "#{services_path}/bale_notifier"
    autoload :LinkCode, "#{services_path}/link_code"
    autoload :BaleActivityLog, "#{services_path}/bale_activity_log"
    autoload :BaleReplyMarkup, "#{services_path}/bale_reply_markup"
    autoload :BaleApiClient, "#{services_path}/bale_api_client"
    autoload :BaleNotificationPayload, "#{services_path}/bale_notification_payload"
    autoload :PluginSetup, "#{services_path}/plugin_setup"

    controllers_path = File.join(
      Rails.root,
      'plugins/discourse-bale-notifications/controllers/discourse_bale_notifications'
    )
    autoload :BaleController, "#{controllers_path}/bale_controller"
    autoload :LinkController, "#{controllers_path}/link_controller"
    autoload :AdminController, "#{controllers_path}/admin_controller"
    autoload :WebhookMessageHandler, "#{controllers_path}/webhook_message_handler"
    autoload :WebhookCallbackHandler, "#{controllers_path}/webhook_callback_handler"

    # Rails engine that owns this plugin's mounted routes.
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseBaleNotifications
    end
  end

  DiscourseBaleNotifications::PluginSetup.configure
end
