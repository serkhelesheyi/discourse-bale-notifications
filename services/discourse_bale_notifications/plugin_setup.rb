# frozen_string_literal: true

module DiscourseBaleNotifications
  # Registers routes, user fields, hooks, and jobs after the Discourse app initializes.
  class PluginSetup
    def self.configure
      draw_engine_routes
      draw_admin_routes
      register_chat_id_field
      register_notification_types_field
      register_notification_event
      register_setting_event
      register_jobs
    end

    def self.draw_engine_routes
      Engine.routes.draw do
        # تغییر مسیر وب‌هوک از /telegram به /bale
        post '/hook/:key' => 'bale#hook'
        # فاز یک - اصلاح #۸: تولید/حذف کد اتصال یک‌بارمصرف (نیازمند ورود به حساب)
        post '/link' => 'link#create'
        delete '/link' => 'link#destroy'
        # فاز سه - اصلاح #۱۵: endpointهای JSON پنل مدیریتی (فقط ادمین)
        get '/admin/status' => 'admin#status'
        post '/admin/test' => 'admin#test'
      end
    end

    def self.draw_admin_routes
      Discourse::Application.routes.append do
        mount ::DiscourseBaleNotifications::Engine, at: '/bale'

        scope '/admin/plugins/discourse-bale-notifications',
              constraints: AdminConstraint.new do
          scope format: false do
            get '/bale-notifications' => 'discourse_bale_notifications/admin#index'
          end
        end
      end
    end

    def self.register_chat_id_field
      DiscoursePluginRegistry.serialized_current_user_fields << 'bale_chat_id'
      User.register_custom_field_type('bale_chat_id', :text)
    end

    # This preference is user-editable; the linked chat ID deliberately is not.
    def self.register_notification_types_field
      DiscoursePluginRegistry.serialized_current_user_fields << 'bale_notification_types'
      User.register_custom_field_type('bale_notification_types', :text)
      register_editable_user_custom_field :bale_notification_types
    end

    # The current push_notification event intentionally respects Discourse's DND behavior.
    def self.register_notification_event
      DiscourseEvent.on(:push_notification) do |user, payload|
        if SiteSetting.bale_notifications_enabled?
          Jobs.enqueue(:send_bale_notifications, user_id: user.id, payload: payload)
        end
      end
    end

    def self.register_setting_event
      DiscourseEvent.on(:site_setting_changed) do |name, _old, _new|
        Jobs.enqueue(:setup_bale_webhook) if %i[bale_notifications_enabled bale_access_token].include?(name)
      end
    end

    def self.register_jobs
      require_dependency 'jobs/base'
      jobs_path = File.join(Rails.root, 'plugins/discourse-bale-notifications/jobs')
      ::Jobs.autoload :SendBaleNotifications, "#{jobs_path}/send_bale_notifications"
      ::Jobs.autoload :SetupBaleWebhook, "#{jobs_path}/setup_bale_webhook"
    end
  end
end
