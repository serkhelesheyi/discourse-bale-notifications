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

      context = delivery_context(args, payload, type_name)
      return unless context

      user, chat_id, post = context
      response = deliver_notification(payload, type_name, user, chat_id, post)
      store_message_id(response, chat_id, post)
    end

    def delivery_context(args, payload, type_name)
      user = User.find(args[:user_id])
      chat_id = user.custom_fields['bale_chat_id']
      return if chat_id.nil? || chat_id.empty?
      return unless user_notification_enabled?(user, type_name)

      [user, chat_id, Post.where(post_number: payload[:post_number], topic_id: payload[:topic_id]).first]
    end
  end
end
