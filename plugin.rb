# frozen_string_literal: true

# name: discourse-bale-notifications
# about: A plugin which posts all user notifications to a bale message
# version: 0.1
# authors: Mohammad Tazari
# url: https://github.com/serkhelesheyi/discourse-bale-notifications
require 'cgi'

# Keep plugin constants and autoloads on the top-level namespace. Discourse evaluates
# plugin.rb in a plugin-instance context, so use explicit root-qualified constants.
Object.const_set(:DiscourseBaleNotifications, Module.new) unless defined?(::DiscourseBaleNotifications)

::DiscourseBaleNotifications.const_set(:PLUGIN_NAME, 'discourse-bale-notifications') unless
  ::DiscourseBaleNotifications.const_defined?(:PLUGIN_NAME, false)

enabled_site_setting :bale_notifications_enabled

register_asset 'stylesheets/common.scss'

# فاز سه - اصلاح #۱۵: افزودن لینک پنل مدیریتی به فهرست «Plugins» در ادمین.
add_admin_route 'bale_notifications.title', 'bale-notifications', use_new_show_route: true

# Register plugin services and controllers on the root namespace explicitly.
plugin_root = __dir__
services_path = File.join(plugin_root, 'services/discourse_bale_notifications')
{
  BaleNotifier: 'bale_notifier',
  LinkCode: 'link_code',
  BaleActivityLog: 'bale_activity_log',
  BaleReplyMarkup: 'bale_reply_markup',
  BaleApiClient: 'bale_api_client',
  BaleNotificationPayload: 'bale_notification_payload',
  PluginSetup: 'plugin_setup'
}.each do |constant_name, file_name|
  ::DiscourseBaleNotifications.autoload(constant_name, File.join(services_path, file_name))
end

controllers_path = File.join(plugin_root, 'controllers/discourse_bale_notifications')
{
  BaleController: 'bale_controller',
  LinkController: 'link_controller',
  AdminController: 'admin_controller',
  WebhookMessageHandler: 'webhook_message_handler',
  WebhookMessageDiagnostics: 'webhook_message_diagnostics',
  WebhookCallbackHandler: 'webhook_callback_handler'
}.each do |constant_name, file_name|
  ::DiscourseBaleNotifications.autoload(constant_name, File.join(controllers_path, file_name))
end

after_initialize do
  # Defer engine construction until after the host application's middleware stack
  # has been initialized. This preserves the plugin's established initialization order.
  ::DiscourseBaleNotifications.const_set(
    :Engine,
    Class.new(::Rails::Engine) do
      engine_name ::DiscourseBaleNotifications::PLUGIN_NAME
      isolate_namespace ::DiscourseBaleNotifications
    end
  )

  ::DiscourseBaleNotifications::PluginSetup.configure
  register_editable_user_custom_field :bale_notification_types
end
