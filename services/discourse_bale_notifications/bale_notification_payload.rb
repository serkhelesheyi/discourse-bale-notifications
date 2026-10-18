# frozen_string_literal: true

module DiscourseBaleNotifications
  # Chooses the safe notification transport and builds its API payload.
  class BaleNotificationPayload
    CAPTION_LIMIT = 1024

    def self.photo?(text, avatar_url)
      SiteSetting.bale_notifications_show_avatar? && avatar_url.present? && text.bytesize <= CAPTION_LIMIT
    end

    def self.photo(text, chat_id, reply_markup, avatar_url, disable_notification)
      {
        chat_id: chat_id,
        photo: avatar_url,
        caption: text,
        disable_notification: disable_notification,
        reply_markup: reply_markup
      }
    end

    def self.text(text, chat_id, reply_markup, disable_notification)
      {
        chat_id: chat_id,
        text: text,
        disable_web_page_preview: true,
        disable_notification: disable_notification,
        reply_markup: reply_markup
      }
    end
  end
end
