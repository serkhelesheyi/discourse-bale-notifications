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

# Autoload plugin services and controllers from stable, plugin-relative paths.
module DiscourseBaleNotifications
  plugin_root = __dir__
  services_path = File.join(plugin_root, 'services/discourse_bale_notifications')
  autoload :BaleNotifier, File.join(services_path, 'bale_notifier')
  autoload :LinkCode, File.join(services_path, 'link_code')
  autoload :BaleActivityLog, File.join(services_path, 'bale_activity_log')
  autoload :BaleReplyMarkup, File.join(services_path, 'bale_reply_markup')
  autoload :BaleApiClient, File.join(services_path, 'bale_api_client')
  autoload :BaleNotificationPayload, File.join(services_path, 'bale_notification_payload')
  autoload :PluginSetup, File.join(services_path, 'plugin_setup')

  controllers_path = File.join(plugin_root, 'controllers/discourse_bale_notifications')
  autoload :BaleController, File.join(controllers_path, 'bale_controller')
  autoload :LinkController, File.join(controllers_path, 'link_controller')
  autoload :AdminController, File.join(controllers_path, 'admin_controller')
  autoload :WebhookMessageHandler, File.join(controllers_path, 'webhook_message_handler')
  autoload :WebhookCallbackHandler, File.join(controllers_path, 'webhook_callback_handler')

  # Rails engine that owns this plugin's mounted routes.
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseBaleNotifications
  end
end

after_initialize do
  DiscourseBaleNotifications::PluginSetup.configure
  register_editable_user_custom_field :bale_notification_types
end
