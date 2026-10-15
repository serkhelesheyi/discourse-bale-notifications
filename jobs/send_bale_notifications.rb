# frozen_string_literal: true

require_dependency 'jobs/base'

module Jobs
  # Delivers a queued Discourse notification to the linked private Bale chat.
  class SendBaleNotifications < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.bale_notifications_enabled?

      payload = args[:payload]
      type_name = Notification.types[payload[:notification_type]].to_s
      return unless site_notification_enabled?(type_name)

      user = User.find(args[:user_id])
      chat_id = user.custom_fields['bale_chat_id']
      return if chat_id.nil? || chat_id.empty?
      return unless user_notification_enabled?(user, type_name)

      post = Post.where(post_number: payload[:post_number], topic_id: payload[:topic_id]).first
      response = deliver_notification(payload, type_name, user, chat_id, post)
      store_message_id(response, chat_id, post)
    end

    def site_notification_enabled?(type_name)
      SiteSetting.bale_enabled_notification_types.split('|').include?(type_name)
    end

    def user_notification_enabled?(user, type_name)
      preferences = user.custom_fields['bale_notification_types']
      preferences.blank? || preferences.split('|').include?(type_name)
    end

    def deliver_notification(payload, type_name, user, chat_id, post)
      message_text = notification_text(payload, type_name, user)
      avatar_url = avatar_url_for(payload[:username])
      DiscourseBaleNotifications::BaleNotifier.send_notification(
        message_text,
        chat_id,
        DiscourseBaleNotifications::BaleNotifier.generate_reply_markup(post, user),
        avatar_url: avatar_url,
        disable_notification: quiet_hours?(user)
      )
    end

    def notification_text(payload, type_name, user)
      I18n.with_locale(user.effective_locale) do
        I18n.t(
          "discourse_bale_notifications.message.#{type_name}",
          site_title: CGI.escapeHTML(SiteSetting.title),
          site_url: Discourse.base_url,
          post_url: CGI.escapeHTML(Discourse.base_url + payload[:post_url].to_s),
          post_excerpt: CGI.escapeHTML(payload[:excerpt]),
          topic: CGI.escapeHTML(payload[:topic_title]),
          username: CGI.escapeHTML(payload[:username]),
          user_url: CGI.escapeHTML("#{Discourse.base_url}/u/#{payload[:username]}")
        )
      end
    end

    def avatar_url_for(username)
      acting_user = User.find_by(username: username)
      return unless acting_user

      "#{Discourse.base_url}#{acting_user.avatar_template.gsub('{size}', '128')}"
    end

    def quiet_hours?(user)
      return false unless SiteSetting.bale_notifications_quiet_hours_enabled?

      zone_name = user.user_option&.timezone.presence || Time.zone.name
      hour = Time.find_zone!(zone_name).now.hour
      quiet_hours_for_hour?(hour)
    rescue ArgumentError
      false
    end

    def quiet_hours_for_hour?(hour)
      start_hour = SiteSetting.bale_notifications_quiet_hours_start
      end_hour = SiteSetting.bale_notifications_quiet_hours_end
      return false if start_hour == end_hour

      if start_hour < end_hour
        hour >= start_hour && hour < end_hour
      else
        hour >= start_hour || hour < end_hour
      end
    end

    def store_message_id(response, chat_id, post)
      return unless response

      message_id = response['result']['message_id']
      PluginStore.set('bale-notifications', "message_#{chat_id}_#{message_id}", post.id)
    end
  end
end
