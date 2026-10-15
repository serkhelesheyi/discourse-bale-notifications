# frozen_string_literal: true

module DiscourseBaleNotifications
  # Handles validated inline-keyboard callbacks received by the Bale webhook.
  module WebhookCallbackHandler
    def handle_callback_query
      payload = params['callback_query']
      return acknowledge_invalid_callback(payload) unless valid_callback_payload?(payload)

      chat_id = payload['message']['chat']['id']
      return render json: { success: true } if rate_limited_chat?(chat_id)

      target = callback_target(payload, chat_id)
      return unless target

      user, post, data = target
      response_text = callback_action_text(data, user, post)
      DiscourseBaleNotifications::BaleNotifier.answer_callback(payload['id'], response_text)
      update_callback_keyboard(payload, chat_id, post, user)
    end

    def acknowledge_invalid_callback(payload)
      callback_id = payload['id'] if webhook_object?(payload)
      if callback_id.present?
        DiscourseBaleNotifications::BaleNotifier.answer_callback(callback_id, unavailable_action_text)
      end
      render json: { success: true }
    end

    def callback_target(payload, chat_id)
      field = UserCustomField.find_by!(name: 'bale_chat_id', value: chat_id.to_s)
      user = User.find(field.user_id)
      data = payload['data'].to_s.split(':')
      post = Post.find(data[1])
      [user, post, data]
    rescue ActiveRecord::RecordNotFound
      DiscourseBaleNotifications::BaleNotifier.answer_callback(payload['id'], unavailable_action_text)
      render json: { success: true }
      nil
    end

    def callback_action_text(data, user, post)
      I18n.with_locale(user.effective_locale) do
        case data[0]
        when 'like'
          like_action_text(user, post)
        when 'unlike'
          unlike_action_text(user, post)
        else
          unavailable_action_text
        end
      end
    end

    def like_action_text(user, post)
      PostActionCreator.create(user, post, :like)
      I18n.t('discourse_bale_notifications.like-success')
    rescue PostAction::AlreadyActed
      I18n.t('discourse_bale_notifications.already-liked')
    rescue Discourse::InvalidAccess
      I18n.t('discourse_bale_notifications.like-failed')
    end

    def unlike_action_text(user, post)
      guardian = Guardian.new(user)
      action_type_id = PostActionType.types[:like]
      post_action = user.post_actions.find_by(
        post_id: post.id,
        post_action_type_id: action_type_id,
        deleted_at: nil
      )
      raise Discourse::NotFound if post_action.blank?

      guardian.ensure_can_delete!(post_action)
      PostAction.remove_act(user, post, action_type_id)
      I18n.t('discourse_bale_notifications.unlike-success')
    rescue Discourse::NotFound, Discourse::InvalidAccess
      I18n.t('discourse_bale_notifications.unlike-failed')
    end

    def unavailable_action_text
      I18n.t(
        'discourse_bale_notifications.action-unavailable',
        default: '❌ This action is no longer available.'
      )
    end

    def update_callback_keyboard(payload, chat_id, post, user)
      message = {
        chat_id: chat_id,
        message_id: payload['message']['message_id'],
        reply_markup: DiscourseBaleNotifications::BaleNotifier.generate_reply_markup(post, user)
      }
      DiscourseBaleNotifications::BaleNotifier.edit_keyboard(message)
    end
  end
end
