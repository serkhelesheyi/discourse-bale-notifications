# frozen_string_literal: true

module DiscourseBaleNotifications
  # Builds the inline keyboard used by notification messages.
  class BaleReplyMarkup
    def self.generate(post, user)
      likes = UserAction.where(action_type: UserAction::LIKE, user_id: user.id, target_post_id: post.id).count
      if likes.positive?
        like_button_text = I18n.t('discourse_bale_notifications.unlike')
        like_button_action = "unlike:#{post.id}"
      else
        like_button_text = I18n.t('discourse_bale_notifications.like')
        like_button_action = "like:#{post.id}"
      end

      post_url = "#{Discourse.base_url}#{post.url({ without_slug: true })}"
      {
        inline_keyboard: [
          [
            { text: like_button_text, callback_data: like_button_action },
            { text: I18n.t('discourse_bale_notifications.view_online'), url: post_url }
          ]
        ]
      }
    end
  end
end
