# frozen_string_literal: true

module DiscourseBaleNotifications
  # Builds the inline keyboard used by notification messages.
  class BaleReplyMarkup
    def self.generate(post, user)
      {
        inline_keyboard: [
          [
            like_button(post, user),
            { text: I18n.t('discourse_bale_notifications.view_online'), url: post_url(post) }
          ]
        ]
      }
    end

    def self.like_button(post, user)
      active_like = PostAction.exists?(
        user_id: user.id,
        post_id: post.id,
        post_action_type_id: PostActionType.types[:like],
        deleted_at: nil
      )
      if active_like
        { text: I18n.t('discourse_bale_notifications.unlike'), callback_data: "unlike:#{post.id}" }
      else
        { text: I18n.t('discourse_bale_notifications.like'), callback_data: "like:#{post.id}" }
      end
    end

    def self.post_url(post)
      "#{Discourse.base_url}#{post.url({ without_slug: true })}"
    end
  end
end
