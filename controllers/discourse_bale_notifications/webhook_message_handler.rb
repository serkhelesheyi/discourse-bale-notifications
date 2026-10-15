# frozen_string_literal: true

module DiscourseBaleNotifications
  # Handles valid private-chat text messages received by the Bale webhook.
  module WebhookMessageHandler
    def handle_message
      incoming = params['message']
      return render json: { success: true } unless valid_message_payload?(incoming)

      chat_id = incoming['chat']['id']
      return render json: { success: true } if rate_limited_chat?(chat_id)

      user, known_user, message_text = resolve_message_user(chat_id, incoming)
      message_text = reply_message_text(user, chat_id, incoming) if known_user && incoming.key?('reply_to_message')

      send_incoming_message(chat_id, message_text)
    end

    def send_incoming_message(chat_id, message_text)
      DiscourseBaleNotifications::BaleNotifier.send_message(
        {
          chat_id: chat_id,
          text: message_text,
          parse_mode: 'html',
          disable_web_page_preview: true
        }
      )
    end

    def resolve_message_user(chat_id, incoming)
      field = UserCustomField.find_by(name: 'bale_chat_id', value: chat_id.to_s)
      user = User.find(field.user_id)
      [user, true, known_user_text(user)]
    rescue Discourse::NotFound, NoMethodError
      resolve_unlinked_user(chat_id, incoming)
    end

    def known_user_text(user)
      I18n.with_locale(user.effective_locale) do
        I18n.t(
          'discourse_bale_notifications.known-user',
          site_title: CGI.escapeHTML(SiteSetting.title),
          username: escape_html(user.username)
        )
      end
    end

    def resolve_unlinked_user(chat_id, incoming)
      code = DiscourseBaleNotifications::LinkCode.consume(incoming['text'].to_s.strip)
      linked_user = code ? User.find_by(id: code) : nil
      return [nil, false, initial_contact_text] unless linked_user

      linked_user.custom_fields['bale_chat_id'] = chat_id.to_s
      linked_user.save_custom_fields
      [linked_user, true, link_success_text(linked_user)]
    end

    def link_success_text(user)
      I18n.with_locale(user.effective_locale) do
        I18n.t(
          'discourse_bale_notifications.link-success',
          site_title: CGI.escapeHTML(SiteSetting.title),
          username: escape_html(user.username)
        )
      end
    end

    def initial_contact_text
      I18n.t(
        'discourse_bale_notifications.initial-contact',
        site_title: CGI.escapeHTML(SiteSetting.title)
      )
    end

    def reply_message_text(user, chat_id, incoming)
      I18n.with_locale(user.effective_locale) do
        post = reply_to_post(chat_id, incoming)
        post ? create_reply(user, incoming, post) : I18n.t('discourse_bale_notifications.reply-error')
      end
    end

    def create_reply(user, incoming, post)
      result = NewPostManager.new(user, reply_attributes(incoming, post)).perform
      reply_result_text(result)
    end

    def reply_attributes(incoming, post)
      {
        raw: incoming['text'],
        topic_id: post.topic_id,
        reply_to_post_number: post.post_number
      }
    end

    def reply_to_post(chat_id, incoming)
      message_id = incoming['reply_to_message']['message_id']
      post_id = PluginStore.get('bale-notifications', "message_#{chat_id}_#{message_id}")
      Post.find(post_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def reply_result_text(result)
      if result.errors.any?
        errors = escape_html(result.errors.full_messages.join("\n"))
        I18n.t('discourse_bale_notifications.reply-failed', errors: errors)
      else
        I18n.t('discourse_bale_notifications.reply-success', post_url: CGI.escapeHTML(result.post.full_url))
      end
    end
  end
end
